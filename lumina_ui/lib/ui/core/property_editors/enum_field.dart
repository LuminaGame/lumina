import 'package:shadcn_flutter/shadcn_flutter.dart';

class EnumField extends StatelessWidget {
  final bool isMixed;
  final String value;
  final List<String> enumValues;
  final ValueChanged<String> onCommit;
  final bool isRadioGroup;

  const EnumField({
    this.isMixed = false,
    super.key,
    required this.value,
    required this.enumValues,
    required this.onCommit,
    this.isRadioGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isRadioGroup) {
      return Wrap(
        spacing: 4,
        children: enumValues.map((e) => Button(
          style: e == value ? const ButtonStyle.primary() : const ButtonStyle.outline(),
          onPressed: () => onCommit(e),
          child: Text(e, style: const TextStyle(fontSize: 9)),
        )).toList(),
      );
    }
    
    return Builder(
      builder: (context) {
        return OutlineButton(
          onPressed: () {
            showOverlay(
              context,
              const DialogConfiguration(),
              builder: (context) {
                return AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: enumValues.map((e) => GhostButton(
                      onPressed: () {
                        onCommit(e);
                        Navigator.of(context).pop();
                      },
                      child: Text(e, style: const TextStyle(fontSize: 9)),
                    )).toList(),
                  ),
                );
              },
            );
          },
          child: Text(isMixed ? '—' : (value.isEmpty ? 'Select...' : value), style: const TextStyle(fontSize: 9)),
        );
      },
    );
  }
}
