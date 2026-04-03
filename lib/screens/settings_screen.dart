import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/research_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _openAiController = TextEditingController();
  final _tavilyController = TextEditingController();
  final _qdrantUrlController = TextEditingController();
  final _qdrantKeyController = TextEditingController();
  String _selectedModel = 'gpt-4o';
  int _maxSteps = 15;
  bool _obscureOpenAi = true;
  bool _obscureTavily = true;
  bool _obscureQdrant = true;

  final _models = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-3.5-turbo',
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final storage = ref.read(storageServiceProvider);
    _openAiController.text = storage.getSetting('openai_api_key') ?? '';
    _tavilyController.text = storage.getSetting('tavily_api_key') ?? '';
    _qdrantUrlController.text =
        storage.getSetting('qdrant_url') ?? 'http://localhost:6333';
    _qdrantKeyController.text = storage.getSetting('qdrant_api_key') ?? '';
    _selectedModel = storage.getSetting('model') ?? 'gpt-4o';
    _maxSteps =
        int.tryParse(storage.getSetting('max_steps') ?? '15') ?? 15;
  }

  Future<void> _saveSettings() async {
    final storage = ref.read(storageServiceProvider);
    await storage.setSetting('openai_api_key', _openAiController.text.trim());
    await storage.setSetting('tavily_api_key', _tavilyController.text.trim());
    await storage.setSetting('qdrant_url', _qdrantUrlController.text.trim());
    await storage.setSetting('qdrant_api_key', _qdrantKeyController.text.trim());
    await storage.setSetting('model', _selectedModel);
    await storage.setSetting('max_steps', _maxSteps.toString());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('설정이 저장되었습니다'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _openAiController.dispose();
    _tavilyController.dispose();
    _qdrantUrlController.dispose();
    _qdrantKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // API 키 섹션
        _SectionHeader(icon: Icons.key, title: 'API 키'),
        const SizedBox(height: 12),
        _ApiKeyField(
          label: 'OpenAI API Key',
          controller: _openAiController,
          obscure: _obscureOpenAi,
          onToggle: () => setState(() => _obscureOpenAi = !_obscureOpenAi),
          hint: 'sk-...',
        ),
        const SizedBox(height: 12),
        _ApiKeyField(
          label: 'Tavily API Key',
          controller: _tavilyController,
          obscure: _obscureTavily,
          onToggle: () => setState(() => _obscureTavily = !_obscureTavily),
          hint: 'tvly-...',
        ),
        const SizedBox(height: 24),

        // Qdrant 섹션
        _SectionHeader(icon: Icons.storage, title: 'Qdrant (벡터 DB)'),
        const SizedBox(height: 12),
        TextField(
          controller: _qdrantUrlController,
          decoration: InputDecoration(
            labelText: 'Qdrant URL',
            hintText: 'http://localhost:6333',
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ApiKeyField(
          label: 'Qdrant API Key (선택)',
          controller: _qdrantKeyController,
          obscure: _obscureQdrant,
          onToggle: () => setState(() => _obscureQdrant = !_obscureQdrant),
          hint: '클라우드 사용 시 입력',
        ),
        const SizedBox(height: 24),

        // 모델 설정
        _SectionHeader(icon: Icons.auto_awesome, title: '모델 설정'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedModel,
              isExpanded: true,
              items: _models
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedModel = v);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Max Steps 슬라이더
        Row(
          children: [
            Expanded(
              child: Text('최대 추론 단계: $_maxSteps',
                  style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
        Slider(
          value: _maxSteps.toDouble(),
          min: 5,
          max: 30,
          divisions: 25,
          label: '$_maxSteps',
          onChanged: (v) => setState(() => _maxSteps = v.round()),
        ),
        const SizedBox(height: 24),

        // 테마 설정
        _SectionHeader(icon: Icons.palette, title: '테마'),
        const SizedBox(height: 12),
        SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(
              value: ThemeMode.system,
              icon: Icon(Icons.brightness_auto),
              label: Text('시스템'),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              icon: Icon(Icons.light_mode),
              label: Text('라이트'),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              icon: Icon(Icons.dark_mode),
              label: Text('다크'),
            ),
          ],
          selected: {themeMode},
          onSelectionChanged: (v) {
            ref.read(themeModeProvider.notifier).state = v.first;
          },
        ),
        const SizedBox(height: 32),

        // 저장 버튼
        FilledButton.icon(
          onPressed: _saveSettings,
          icon: const Icon(Icons.save),
          label: const Text('설정 저장'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 앱 정보
        Center(
          child: Text(
            'ResearchArch v1.0.0',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ApiKeyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String hint;

  const _ApiKeyField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
