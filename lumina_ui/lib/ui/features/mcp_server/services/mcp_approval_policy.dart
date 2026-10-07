import 'package:lumina_ui/ui/features/mcp_server/services/mcp_tool_risk.dart';
import 'package:lumina_editor_api/lumina_editor_api.dart' show McpApprovalPolicy, McpApprovalDecision, McpCallContext;

// The call context, decision and policy interface live in
// lumina_editor_api (a plugin registers policies); re-exported here.
export 'package:lumina_editor_api/lumina_editor_api.dart' show McpTransport, McpCallContext, McpApprovalDecision, McpApprovalPolicy;

/// The default: every call runs, as before approvals existed.
class AllowAllPolicy implements McpApprovalPolicy {
  const AllowAllPolicy();

  @override
  McpApprovalDecision review(McpCallContext call) => const McpApprovalDecision.allow();
}

/// The panel's "External agents may run" ceiling: a call above
/// [maxRisk] is refused (and its tool is not listed).
class McpRiskCeilingPolicy implements McpApprovalPolicy {
  final McpToolRisk Function() maxRisk;

  const McpRiskCeilingPolicy(this.maxRisk);

  @override
  McpApprovalDecision review(McpCallContext call) {
    final ceiling = maxRisk();
    if (call.risk <= ceiling) return const McpApprovalDecision.allow();
    return McpApprovalDecision.deny(
        '${call.tool} is a ${call.risk.name} tool; the editor allows external agents up to ${ceiling.name} '
        '(AI Agent Access → External agents may run).');
  }
}
