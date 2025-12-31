import 'package:flutter/material.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/features/catalog/presentation/template/template_picker_view_model.dart';

class TemplatePickerArgs {
  const TemplatePickerArgs({required this.catalogId});
  final String catalogId;
}

class TemplatePickerPage extends StatefulWidget {
  const TemplatePickerPage({super.key, required this.args});

  final TemplatePickerArgs args;

  static TemplatePickerPage fromSettings(RouteSettings settings) {
    final args = settings.arguments as TemplatePickerArgs?;
    if (args == null) {
      throw StateError('TemplatePickerArgs required');
    }
    return TemplatePickerPage(args: args);
  }

  @override
  State<TemplatePickerPage> createState() => _TemplatePickerPageState();
}

class _TemplatePickerPageState extends State<TemplatePickerPage> {
  TemplatePickerViewModel? _vm;
  var _didInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;
    final repo = AppScope.of(context).catalogRepository;
    _vm = TemplatePickerViewModel(repository: repo, catalogId: widget.args.catalogId)
      ..load();
  }

  @override
  void dispose() {
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        final selected = vm.selectedTemplateId;
        return Scaffold(
          appBar: AppBar(title: const Text('Şablon seç')),
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vm.templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final t = vm.templates[index];
              return ListTile(
                title: Text(t.title),
                subtitle: Text(t.subtitle),
                trailing: selected == t.id ? const Icon(Icons.check) : null,
                onTap: () async {
                  await vm.select(t.id);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        );
      },
    );
  }
}
