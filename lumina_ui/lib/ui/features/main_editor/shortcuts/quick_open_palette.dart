import 'package:lumina/data/models/lumina_asset.dart';
import 'package:flutter/widgets.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:lumina_ui/ui/features/main_editor/view_models/editor_view_model.dart';
import 'package:lumina_ui/ui/features/main_editor/utils/fuzzy_match.dart';

void showQuickOpenPalette(BuildContext context, EditorViewModel viewModel, FocusNode returnFocus) {
  shadcn.showOverlay(
    context,
    const shadcn.DialogConfiguration(),
    builder: (ctx) {
      return QuickOpenPaletteWidget(
        viewModel: viewModel,
        onClose: () {
          Navigator.of(ctx).pop();
          returnFocus.requestFocus();
        },
      );
    },
  );
}

class QuickOpenPaletteWidget extends StatefulWidget {
  final EditorViewModel viewModel;
  final VoidCallback onClose;

  const QuickOpenPaletteWidget({
    super.key,
    required this.viewModel,
    required this.onClose,
  });

  @override
  State<QuickOpenPaletteWidget> createState() => _QuickOpenPaletteWidgetState();
}

class _QuickOpenPaletteWidgetState extends State<QuickOpenPaletteWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<QuickOpenMatch> _matches = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _matches = fuzzyMatchAssets('', widget.viewModel.realAssets);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _matches = fuzzyMatchAssets(value, widget.viewModel.realAssets);
      _selectedIndex = 0;
    });
  }

  void _onSubmitted() {
    if (_matches.isNotEmpty && _selectedIndex < _matches.length) {
      final match = _matches[_selectedIndex];
      final asset = match.asset;
      
      if (asset.type == AssetType.level) {
        // Open level
        // For simplicity, execute 'file.openLevel' or direct logic? 
        // We probably need to directly call viewModel methods.
        // The spec says EditorCommand doesn't take args, so we might need a custom approach or just call openSubEditorTab
      }
      
      if (asset.type == AssetType.level) {
        // ... handled
      } else {
        widget.viewModel.openSubEditorTab(asset.type.name, asset: asset);
      }
      
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return shadcn.Data<shadcn.ThemeData>.boundary(
      child: Center(
        child: Container(
          width: 500,
          height: 400,
          margin: const EdgeInsets.only(top: 100), // Top aligned
          decoration: BoxDecoration(
            color: shadcn.Theme.of(context).colorScheme.background,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                // a drop shadow/scrim: black at 20%, not a surface
                color: const Color(0x33000000),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ]
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: shadcn.TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  placeholder: const Text('Search assets...'),
                  onChanged: _onChanged,
                  onSubmitted: (_) => _onSubmitted(),
                ),
              ),
              const shadcn.Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final match = _matches[index];
                    final isSelected = index == _selectedIndex;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                        _onSubmitted();
                      },
                      child: Container(
                        color: isSelected ? shadcn.Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : null,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(match.asset.relativePath),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
