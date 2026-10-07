import 'package:lumina_marketplace_shared/lumina_marketplace_shared.dart';

import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/marketplace/services/marketplace_license_records.dart';
import 'package:lumina_ui/ui/features/marketplace/view_models/marketplace_view_model.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_jobs.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_protocol.dart';
import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool.dart';
import 'package:lumina_ui/ui/features/mcp_server/tools/content_tools.dart' show mcpContentFolder;

/// What every account-bound Marketplace tool says when nobody is signed in:
/// credentials stay with the user.
const String kMcpMarketplaceSignIn = 'Sign in in Window → Marketplace; agents cannot sign in.';

/// Window → Marketplace as MCP tools (groups `content` +
/// `plugin`): status, search, a listing's details, Get (Free) and Add to
/// Project / Install as a job, what is installed. There is no sign-in, no
/// sign-out and no uninstall tool, and no call returns a token or session.
void registerMarketplaceTools(McpToolRegistry registry, EditorViewModel vm, McpJobRegistry jobs) {
  const groups = {McpToolGroups.content, McpToolGroups.plugin};

  Future<MarketplaceViewModel> market() async {
    final m = vm.marketplace;
    await m.start();
    return m;
  }

  Map<String, Object?> listingJson(MarketplaceViewModel m, Listing l) => {
        'id': l.id,
        'slug': l.slug,
        'title': l.title,
        'publisher': {'username': l.publisher.username, 'display_name': l.publisher.displayName},
        'category': l.category.wire,
        'install_kind': l.category.installKind.wire,
        'latest_version': l.latestVersion?.version,
        'licenses': l.licenses.ids,
        'in_library': m.inLibrary(l),
        'installed': m.installedRecord(l.id) != null,
      };

  Map<String, Object?> recordJson(MarketplaceInstallRecord r) => {
        'id': r.listingId,
        'title': r.title,
        'installed_to': r.installedTo,
        'version': r.version,
        'install_kind': r.installKind.wire,
        'licenses': [for (final l in r.licenses) l.id],
        'license_file': r.licenseFile,
        'attribution_required': r.attributionRequired,
        'files': r.files,
      };

  Future<Listing> fetch(MarketplaceViewModel m, String id) async {
    try {
      return await m.service.listing(id);
    } catch (e) {
      throw JsonRpcException(JsonRpcErrorCode.invalidParams,
          'No Marketplace listing "$id" on ${m.serverUrl} ($e). marketplace_search lists the ids.');
    }
  }

  registry.registerAll([
    McpTool(
      name: 'marketplace_status',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Marketplace status',
      description: 'The Marketplace server (Editor Preferences → Marketplace Server) and whether the user is signed in '
          '(user {username, display_name}). Never returns a token or session. When signed out, ask the user to sign '
          'in in Window → Marketplace; agents cannot sign in.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final m = await market();
        final u = m.user;
        return McpToolResult.json({
          'server_url': m.serverUrl.toString(),
          'signed_in': m.isSignedIn,
          'user': u == null ? null : {'username': u.username, 'display_name': u.displayName},
          'library_count': m.library.length,
          'installed_count': m.installed.length,
        });
      },
    ),
    McpTool(
      name: 'marketplace_search',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Search the Marketplace',
      description: 'Searches the Marketplace catalogue (the window\'s Browse view): {total, results[{id, title, '
          'publisher, category, install_kind, latest_version, licenses, in_library, installed}]}.',
      inputSchema: McpSchema.object({
        'query': McpSchema.string('Text to search titles, descriptions and tags.'),
        'category': McpSchema.string('Only this category.', enumValues: [for (final c in ListingCategory.values) c.wire]),
      }),
      handler: (args) async {
        final m = await market();
        final wire = args.optionalString('category');
        await m.search(query: args.optionalString('query') ?? '', category: ListingCategory.tryParse(wire), clearCategory: wire == null);
        if (m.searchError != null) return McpToolResult.error('Marketplace search failed: ${m.searchError}');
        return McpToolResult.json({
          'server_url': m.serverUrl.toString(),
          'total': m.total,
          'results': [for (final l in m.results) listingJson(m, l)],
        });
      },
    ),
    McpTool(
      name: 'marketplace_get_listing',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'Get Marketplace listing',
      description: 'One listing as its detail page shows it: description, versions, licenses, screenshot URLs, '
          'can_install and the install button\'s label (Add to Project, Install Plugin, …).',
      inputSchema: McpSchema.object({'id': McpSchema.string('The listing id (or slug) from marketplace_search.')}, required: ['id']),
      handler: (args) async {
        final m = await market();
        final listing = await fetch(m, args.string('id'));
        await m.select(listing);
        final l = m.selected?.id == listing.id ? m.selected! : listing;
        return McpToolResult.json({
          ...listingJson(m, l),
          'description': l.description,
          'tags': l.tags,
          'engine_version': l.engineVersion,
          'price_cents': l.priceCents,
          'download_count': l.downloadCount,
          'versions': [
            for (final v in l.versions ?? [?l.latestVersion])
              {'version': v.version, 'released': v.createdAt.toIso8601String(), 'size': v.size, 'licenses': v.licenses.ids, 'notes': v.releaseNotes},
          ],
          'screenshots': [for (final s in l.screenshots) m.serverUrl.resolve(s).toString()],
          'can_install': m.canInstall(l),
          'install_label': MarketplaceViewModel.installLabel(l.category),
        });
      },
    ),
    McpTool(
      name: 'marketplace_add_to_library',
      risk: McpToolRisk.external,
      groups: groups,
      title: 'Add Marketplace listing to library',
      description: 'The listing page\'s "Get (Free)": adds a free listing to the signed-in user\'s library on the '
          'server. $kMcpMarketplaceSignIn',
      inputSchema: McpSchema.object({'id': McpSchema.string('The listing id (or slug).')}, required: ['id']),
      handler: (args) async {
        final m = await market();
        if (!m.isSignedIn) return McpToolResult.error(kMcpMarketplaceSignIn);
        final listing = await fetch(m, args.string('id'));
        if (!await m.get(listing)) return McpToolResult.error('Could not get ${listing.title}: ${m.sessionError ?? 'see the Output Log'}');
        return McpToolResult.json({'id': listing.id, 'title': listing.title, 'in_library': m.inLibrary(listing)});
      },
    ),
    McpTool(
      name: 'marketplace_install',
      risk: McpToolRisk.external,
      groups: groups,
      title: 'Install from the Marketplace',
      description: 'Add to Project / Install Plugin / Install Theme: opens Window → Marketplace and downloads, verifies '
          'and installs the listing\'s latest version as a job (kind marketplace_install; progress follows the '
          'download, cancel_job stops it and installs nothing). An asset listing lands in `folder` (default '
          'contents/Marketplace/<Publisher>/<Listing>) with its LICENSE notice; a plugin is installed disabled — call '
          'set_plugin_enabled. The result is the install record. $kMcpMarketplaceSignIn Removing an install is the '
          'user\'s: Window → Marketplace → Installed.',
      inputSchema: McpSchema.object({
        'id': McpSchema.string('The listing id (or slug).'),
        'folder': McpSchema.string('For an asset listing: the Content Browser folder to install into, e.g. "contents/Marketplace".'),
      }, required: ['id']),
      handler: (args) async {
        final m = await market();
        final folderArg = args.optionalString('folder');
        final folder = folderArg == null ? null : mcpContentFolder(folderArg);
        if (!m.isSignedIn) return McpToolResult.error(kMcpMarketplaceSignIn);
        final listing = await fetch(m, args.string('id'));
        if (!m.canInstall(listing)) {
          return McpToolResult.error('${listing.title} cannot be installed from here (no published version, or an asset '
              'listing without an open project).');
        }
        vm.openMarketplace();
        final job = jobs.start(
          'marketplace_install',
          title: '${MarketplaceViewModel.installLabel(listing.category)}: ${listing.title}',
          exclusive: 'marketplace:${listing.id}',
          cancel: () => m.cancelInstall(listing.id),
          run: (job) async {
            String? phase;
            void follow() {
              final p = m.job(listing.id)?.progress;
              if (p == null) return;
              if (p.phase.name != phase) {
                phase = p.phase.name;
                job.addLog('${p.phase.name}${p.message.isEmpty ? '' : ': ${p.message}'}', source: 'Marketplace');
              }
              job.update(progress: p.fraction, stage: p.phase.name);
            }

            m.addListener(follow);
            try {
              final record = await m.install(listing, folder: folder);
              if (record == null) {
                final why = m.job(listing.id)?.error ?? m.sessionError ?? 'cancelled; nothing was installed';
                throw McpJobFailure('Install of ${listing.title} failed: $why');
              }
              job.addLog('Installed ${record.title} ${record.version} into ${record.installedTo}', source: 'Marketplace');
              return {
                ...recordJson(record),
                if (record.installKind == InstallKind.plugin)
                  'next': 'The plugin is installed disabled; call set_plugin_enabled to enable it.',
              };
            } finally {
              m.removeListener(follow);
            }
          },
        );
        return McpToolResult.json({'job_id': job.id, 'state': job.state.name, 'id': listing.id, 'title': listing.title});
      },
    ),
    McpTool(
      name: 'marketplace_list_installed',
      risk: McpToolRisk.readOnly,
      groups: groups,
      title: 'List Marketplace installs',
      description: 'What the Marketplace installed (Window → Marketplace → Installed): {id, title, installed_to, '
          'version, install_kind, licenses, license_file}.',
      inputSchema: McpSchema.object(const {}),
      handler: (args) async {
        final m = await market();
        m.refreshInstalled();
        return McpToolResult.json({'installed': [for (final r in m.installed) recordJson(r)]});
      },
    ),
  ]);
}
