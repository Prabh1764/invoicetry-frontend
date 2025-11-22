import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/api_client.dart';
import '../../data/services/pdf_service.dart';
import '../../data/services/settings_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/primary_button.dart';

// Conditionally import webview based on platform
import 'customize_pdf_screen_stub.dart'
    if (dart.library.html) 'customize_pdf_screen_web.dart' as webview_impl;

class CustomizePdfScreen extends ConsumerStatefulWidget {
  final String invoiceId;

  const CustomizePdfScreen({super.key, required this.invoiceId});

  @override
  ConsumerState<CustomizePdfScreen> createState() => _CustomizePdfScreenState();
}

class _CustomizePdfScreenState extends ConsumerState<CustomizePdfScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _templates = [];
  List<String> _categories = [];
  bool _isLoadingTemplates = false;
  
  // Colors
  Color _primaryColor = Colors.black;
  Color _secondaryColor = Colors.grey;
  Color _accentColor = Colors.black;
  Color _backgroundColor = Colors.white;
  
  // Watermark
  bool _watermarkEnabled = false;
  String _watermarkText = '';
  int _watermarkOpacity = 5;
  
  // Table & Layout
  String _tableStyle = 'bordered'; // bordered, minimal, striped
  String _layoutStyle = 'modern'; // modern, classic, minimal
  String _fontFamily = 'Arial'; // Arial, Helvetica, Times, Georgia
  
  // Preview
  String? _previewHtml;
  bool _isLoadingPreview = false;
  bool _isExtractingColors = false;
  bool _isAnalyzingDesign = false;
  Timer? _debounceTimer;
  Widget? _previewWidget;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // 6 tabs (removed AI Design)
    _loadTemplates();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _loadPreview();
    });
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      final apiClient = ApiClient();
      final pdfService = PdfService(apiClient);
      final result = await pdfService.getTemplates();
      
      if (mounted) {
        setState(() {
          _templates = (result['templates'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _categories = (result['categories'] as List?)?.cast<String>() ?? [];
          _isLoadingTemplates = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading templates: $e');
      if (mounted) {
        setState(() => _isLoadingTemplates = false);
      }
    }
  }

  // Layout-specific state
  String? _headerStyle;
  String? _spacing;
  String? _borderStyle;
  String? _footerStyle;

  Future<void> _applyTemplate(Map<String, dynamic> template) async {
    try {
      final colors = template['colors'] as Map<String, dynamic>;
      final watermark = template['watermark'] as Map<String, dynamic>;
      
      setState(() {
        _primaryColor = _hexToColor(colors['primary'] as String? ?? '#000000');
        _secondaryColor = _hexToColor(colors['secondary'] as String? ?? '#666666');
        _accentColor = _hexToColor(colors['accent'] as String? ?? '#000000');
        _backgroundColor = _hexToColor(colors['background'] as String? ?? '#FFFFFF');
        _tableStyle = template['tableStyle'] as String? ?? 'bordered';
        _layoutStyle = template['layoutStyle'] as String? ?? 'modern';
        _fontFamily = template['fontFamily'] as String? ?? 'Arial';
        _watermarkEnabled = watermark['enabled'] as bool? ?? false;
        _watermarkText = watermark['text'] as String? ?? '';
        _watermarkOpacity = (watermark['opacity'] as num? ?? 5).toInt();
        // Apply layout-specific settings
        _headerStyle = template['headerStyle'] as String?;
        _spacing = template['spacing'] as String?;
        _borderStyle = template['borderStyle'] as String?;
        _footerStyle = template['footerStyle'] as String?;
      });
      
      _updatePreview();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Template "${template['name']}" applied!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error applying template: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to apply template: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final apiClient = ApiClient();
      final settingsService = SettingsService(apiClient);
      final settings = await settingsService.getSettings();
      
      if (mounted) {
        setState(() {
          if (settings.pdfPrimaryColor != null) {
            _primaryColor = _hexToColor(settings.pdfPrimaryColor!);
          }
          if (settings.pdfSecondaryColor != null) {
            _secondaryColor = _hexToColor(settings.pdfSecondaryColor!);
          }
          if (settings.pdfAccentColor != null) {
            _accentColor = _hexToColor(settings.pdfAccentColor!);
          }
          if (settings.pdfBackgroundColor != null) {
            _backgroundColor = _hexToColor(settings.pdfBackgroundColor!);
          }
          _watermarkEnabled = settings.pdfWatermarkEnabled ?? false;
          _watermarkText = settings.pdfWatermarkText ?? settings.companyName ?? '';
          _watermarkOpacity = settings.pdfWatermarkOpacity ?? 5;
          _tableStyle = settings.pdfTableStyle ?? 'bordered';
          _layoutStyle = settings.pdfLayoutStyle ?? 'modern';
          _fontFamily = settings.pdfFontFamily ?? 'Arial';
        });
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    }
  }

  void _loadPreview() {
    _updatePreview();
  }

  bool _isPreviewUpdateInProgress = false;

  void _updatePreview() {
    _debounceTimer?.cancel();
    if (!mounted || _isPreviewUpdateInProgress) return;
    
    if (mounted) {
      setState(() {
        _isLoadingPreview = true;
      });
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _isPreviewUpdateInProgress) return;
      
      _isPreviewUpdateInProgress = true;

      try {
        final apiClient = ApiClient();
        final pdfService = PdfService(apiClient);

        final html = await pdfService.generatePreview(
          widget.invoiceId,
          customization: {
            'primaryColor': _colorToHex(_primaryColor),
            'secondaryColor': _colorToHex(_secondaryColor),
            'accentColor': _colorToHex(_accentColor),
            'backgroundColor': _colorToHex(_backgroundColor),
            'watermarkEnabled': _watermarkEnabled,
            'watermarkText': _watermarkText,
            'watermarkOpacity': _watermarkOpacity,
            'tableStyle': _tableStyle,
            'layoutStyle': _layoutStyle,
            'fontFamily': _fontFamily,
            'headerStyle': _headerStyle,
            'spacing': _spacing,
            'borderStyle': _borderStyle,
            'footerStyle': _footerStyle,
          },
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw Exception('Preview request timed out'),
        );

        if (!mounted) {
          _isPreviewUpdateInProgress = false;
          return;
        }

        setState(() {
          _previewHtml = html;
          _isLoadingPreview = false;
          _isPreviewUpdateInProgress = false;
        });

        if (html.isNotEmpty) {
          try {
            _previewWidget = webview_impl.createPreviewWidget(html, apiClient.baseUrl);
            setState(() {});
          } catch (webViewError) {
            debugPrint('Error creating preview widget: $webViewError');
          }
        }
      } catch (e) {
        debugPrint('Error in _updatePreview: $e');
        if (!mounted) {
          _isPreviewUpdateInProgress = false;
          return;
        }
        
        setState(() {
          _isLoadingPreview = false;
          _isPreviewUpdateInProgress = false;
        });
      }
    });
  }

  Future<void> _extractColorsFromLogo() async {
    if (_isExtractingColors) return;
    
    setState(() => _isExtractingColors = true);

    try {
      final apiClient = ApiClient();
      final settingsService = SettingsService(apiClient);
      final settings = await settingsService.getSettings();
      
      if (settings.companyLogoUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please upload a company logo in Settings first'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final pdfService = PdfService(apiClient);
      final logoUrl = settingsService.getLogoUrl(settings.companyLogoUrl);
      if (logoUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid logo URL'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      final colors = await pdfService.extractColorsFromLogo(logoUrl);

      if (!mounted) {
        _isExtractingColors = false;
        return;
      }

      setState(() {
        _primaryColor = _hexToColor(colors['primary'] ?? '#000000');
        _secondaryColor = _hexToColor(colors['secondary'] ?? '#666666');
        _accentColor = _hexToColor(colors['accent'] ?? '#000000');
        _isExtractingColors = false;
      });
      _updatePreview();
    } catch (e) {
      debugPrint('Error extracting colors: $e');
      if (mounted) {
        setState(() => _isExtractingColors = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract colors: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _analyzeReferenceDesign() async {
    if (_isAnalyzingDesign) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isAnalyzingDesign = true);

    try {
      final apiClient = ApiClient();
      final pdfService = PdfService(apiClient);

      // Upload and analyze the image (pass XFile directly, not path)
      final result = await pdfService.uploadAndAnalyzeDesign(image);
      
      debugPrint('📊 [DESIGN_ANALYSIS] Full result: $result');
      
      if (result.containsKey('analysis')) {
        final analysis = result['analysis'] as Map<String, dynamic>;
        debugPrint('📊 [DESIGN_ANALYSIS] Analysis data: $analysis');
        
        // Extract colors
        if (analysis.containsKey('colors')) {
          final colors = analysis['colors'] as Map<String, dynamic>;
          debugPrint('🎨 [DESIGN_ANALYSIS] Colors: $colors');
          setState(() {
            _primaryColor = _hexToColor(colors['primary'] as String? ?? '#000000');
            _secondaryColor = _hexToColor(colors['secondary'] as String? ?? '#666666');
            _accentColor = _hexToColor(colors['accent'] as String? ?? '#000000');
            _backgroundColor = _hexToColor(colors['background'] as String? ?? '#FFFFFF');
          });
        }
        
        // Extract table style
        if (analysis.containsKey('tableStyle')) {
          final tableStyle = analysis['tableStyle'] as String? ?? 'bordered';
          debugPrint('📋 [DESIGN_ANALYSIS] Table Style: $tableStyle');
          setState(() {
            _tableStyle = tableStyle;
          });
        }
        
        // Extract layout style
        if (analysis.containsKey('layoutStyle')) {
          final layoutStyle = analysis['layoutStyle'] as String? ?? 'modern';
          debugPrint('📐 [DESIGN_ANALYSIS] Layout Style: $layoutStyle');
          setState(() {
            _layoutStyle = layoutStyle;
          });
        }
        
        // Extract font family
        if (analysis.containsKey('fontFamily')) {
          final fontFamily = analysis['fontFamily'] as String? ?? 'Arial';
          debugPrint('🔤 [DESIGN_ANALYSIS] Font Family: $fontFamily');
          setState(() {
            _fontFamily = fontFamily;
          });
        }
        
        // Extract watermark settings
        if (analysis.containsKey('watermark')) {
          final watermark = analysis['watermark'] as Map<String, dynamic>;
          debugPrint('💧 [DESIGN_ANALYSIS] Watermark: $watermark');
          setState(() {
            _watermarkEnabled = watermark['enabled'] as bool? ?? false;
            _watermarkText = watermark['text'] as String? ?? '';
            _watermarkOpacity = (watermark['opacity'] as num? ?? 5).toInt();
          });
        }
        
        debugPrint('✅ [DESIGN_ANALYSIS] All settings updated, updating preview...');
        
        // Update preview with new settings
        _updatePreview();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Design analyzed! Updated: Colors, Table (${_tableStyle}), Layout (${_layoutStyle}), Font (${_fontFamily})'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        debugPrint('❌ [DESIGN_ANALYSIS] No analysis in result');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Analysis completed but no design data found'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error analyzing design: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to analyze design: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingDesign = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!mounted) return;

    try {
      final apiClient = ApiClient();
      final settingsService = SettingsService(apiClient);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Saving settings...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      await settingsService.updateSettings({
        'pdfPrimaryColor': _colorToHex(_primaryColor),
        'pdfSecondaryColor': _colorToHex(_secondaryColor),
        'pdfAccentColor': _colorToHex(_accentColor),
        'pdfBackgroundColor': _colorToHex(_backgroundColor),
        'pdfWatermarkEnabled': _watermarkEnabled,
        'pdfWatermarkText': _watermarkText,
        'pdfWatermarkOpacity': _watermarkOpacity,
        'pdfTableStyle': _tableStyle,
        'pdfLayoutStyle': _layoutStyle,
        'pdfFontFamily': _fontFamily,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  Future<void> _showColorPicker(
    Color currentColor,
    Function(Color) onColorChanged,
    String label,
  ) async {
    if (!mounted) return;
    
    final selectedColorResult = await showDialog<Color>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return _SimpleColorPickerDialog(
          initialColor: currentColor,
          label: label,
        );
      },
    );
    
    if (mounted && selectedColorResult != null) {
      onColorChanged(selectedColorResult);
      _updatePreview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize PDF'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.style), text: 'Templates'),
            Tab(icon: Icon(Icons.palette), text: 'Colors'),
            Tab(icon: Icon(Icons.water_drop), text: 'Watermark'),
            Tab(icon: Icon(Icons.table_chart), text: 'Table'),
            Tab(icon: Icon(Icons.view_quilt), text: 'Layout'),
            Tab(icon: Icon(Icons.text_fields), text: 'Typography'),
          ],
        ),
      ),
      body: Row(
        children: [
          // Left: Customization controls
          Expanded(
            flex: 1,
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTemplatesTab(),
                        _buildColorsTab(),
                        _buildWatermarkTab(),
                        _buildTableTab(),
                        _buildLayoutTab(),
                        _buildTypographyTab(),
                      ],
                    ),
                  ),
                  // Save button at bottom
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        PrimaryButton(
                          onPressed: _saveSettings,
                          label: 'Save Design',
                          icon: Icons.save,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Right: Live preview
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[200],
              child: _isLoadingPreview
                  ? const Center(child: CircularProgressIndicator())
                  : _previewHtml == null
                      ? const Center(child: Text('Loading preview...'))
                      : _previewWidget ?? const Center(child: Text('Preview not available')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatesTab() {
    if (_isLoadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }

    // Group templates by category
    final Map<String, List<Map<String, dynamic>>> templatesByCategory = {};
    for (final template in _templates) {
      final category = template['category'] as String? ?? 'other';
      templatesByCategory.putIfAbsent(category, () => []).add(template);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose a Template',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select from ${_templates.length} professional invoice templates. Each template includes colors, layout, table style, and typography.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...templatesByCategory.entries.map((entry) {
            final category = entry.key;
            final templates = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Text(
                    category.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final template = templates[index];
                    final colors = template['colors'] as Map<String, dynamic>;
                    final primaryColor = _hexToColor(colors['primary'] as String? ?? '#000000');
                    
                    return InkWell(
                      onTap: () => _applyTemplate(template),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  template['name']?.toString().substring(0, 1).toUpperCase() ?? 'T',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              template['name'] as String? ?? 'Template',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              template['preview'] as String? ?? '',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildColorsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Color Scheme',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _ColorPickerRow(
                  label: 'Primary Color',
                  color: _primaryColor,
                  onTap: () => _showColorPicker(
                    _primaryColor,
                    (color) => setState(() => _primaryColor = color),
                    'Primary',
                  ),
                ),
                const SizedBox(height: 12),
                _ColorPickerRow(
                  label: 'Secondary Color',
                  color: _secondaryColor,
                  onTap: () => _showColorPicker(
                    _secondaryColor,
                    (color) => setState(() => _secondaryColor = color),
                    'Secondary',
                  ),
                ),
                const SizedBox(height: 12),
                _ColorPickerRow(
                  label: 'Accent Color',
                  color: _accentColor,
                  onTap: () => _showColorPicker(
                    _accentColor,
                    (color) => setState(() => _accentColor = color),
                    'Accent',
                  ),
                ),
                const SizedBox(height: 12),
                _ColorPickerRow(
                  label: 'Background Color',
                  color: _backgroundColor,
                  onTap: () => _showColorPicker(
                    _backgroundColor,
                    (color) => setState(() => _backgroundColor = color),
                    'Background',
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  onPressed: _isExtractingColors ? null : _extractColorsFromLogo,
                  icon: Icons.auto_awesome,
                  label: _isExtractingColors ? 'Extracting...' : 'Extract from Logo',
                  isLoading: _isExtractingColors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatermarkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Watermark Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Enable Watermark'),
                  value: _watermarkEnabled,
                  onChanged: (value) {
                    setState(() {
                      _watermarkEnabled = value;
                    });
                    _updatePreview();
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Watermark Text',
                    hintText: 'Company Name',
                  ),
                  enabled: _watermarkEnabled,
                  onChanged: (value) {
                    setState(() {
                      _watermarkText = value;
                    });
                    _updatePreview();
                  },
                  controller: TextEditingController(text: _watermarkText),
                ),
                const SizedBox(height: 16),
                Text('Opacity: ${_watermarkOpacity}%'),
                Slider(
                  value: _watermarkOpacity.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_watermarkOpacity}%',
                  onChanged: _watermarkEnabled ? (value) {
                    setState(() {
                      _watermarkOpacity = value.toInt();
                    });
                    _updatePreview();
                  } : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Table Style',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _StyleOption(
                  title: 'Bordered',
                  description: 'Full borders around cells, colored headers',
                  isSelected: _tableStyle == 'bordered',
                  onTap: () {
                    setState(() => _tableStyle = 'bordered');
                    _updatePreview();
                  },
                ),
                const SizedBox(height: 12),
                _StyleOption(
                  title: 'Minimal',
                  description: 'No borders, clean lines, subtle separators',
                  isSelected: _tableStyle == 'minimal',
                  onTap: () {
                    setState(() => _tableStyle = 'minimal');
                    _updatePreview();
                  },
                ),
                const SizedBox(height: 12),
                _StyleOption(
                  title: 'Striped',
                  description: 'Alternating row colors, no borders',
                  isSelected: _tableStyle == 'striped',
                  onTap: () {
                    setState(() => _tableStyle = 'striped');
                    _updatePreview();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayoutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Layout Style',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _StyleOption(
                  title: 'Modern',
                  description: 'Clean, spacious, contemporary design',
                  isSelected: _layoutStyle == 'modern',
                  onTap: () {
                    setState(() => _layoutStyle = 'modern');
                    _updatePreview();
                  },
                ),
                const SizedBox(height: 12),
                _StyleOption(
                  title: 'Classic',
                  description: 'Traditional, formal, structured design',
                  isSelected: _layoutStyle == 'classic',
                  onTap: () {
                    setState(() => _layoutStyle = 'classic');
                    _updatePreview();
                  },
                ),
                const SizedBox(height: 12),
                _StyleOption(
                  title: 'Minimal',
                  description: 'Very clean, minimal elements, lots of white space',
                  isSelected: _layoutStyle == 'minimal',
                  onTap: () {
                    setState(() => _layoutStyle = 'minimal');
                    _updatePreview();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypographyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Font Family',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _StyleOption(
                  title: 'Arial',
                  description: 'Sans-serif, modern',
                  isSelected: _fontFamily == 'Arial',
                  onTap: () {
                    setState(() => _fontFamily = 'Arial');
                    _updatePreview();
                  },
                ),
                const SizedBox(height: 12),
                _StyleOption(
                  title: 'Helvetica',
                  description: 'Sans-serif, clean',
                  isSelected: _fontFamily == 'Helvetica',
                  onTap: () {
                    setState(() => _fontFamily = 'Helvetica');
                    _updatePreview();
                  },
                ),
                const SizedBox(height: 12),
                _StyleOption(
                  title: 'Times',
                  description: 'Serif, traditional',
                  isSelected: _fontFamily == 'Times',
                  onTap: () {
                    setState(() => _fontFamily = 'Times');
                    _updatePreview();
                  },
                ),
                const SizedBox(height: 12),
                _StyleOption(
                  title: 'Georgia',
                  description: 'Serif, elegant',
                  isSelected: _fontFamily == 'Georgia',
                  onTap: () {
                    setState(() => _fontFamily = 'Georgia');
                    _updatePreview();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIDesignTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'AI Design Analysis',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload a reference invoice or design image, and AI will extract all design patterns automatically.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  onPressed: _isAnalyzingDesign ? null : _analyzeReferenceDesign,
                  icon: Icons.upload_file,
                  label: _isAnalyzingDesign ? 'Analyzing...' : 'Upload Reference Design',
                  isLoading: _isAnalyzingDesign,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'Quick Actions',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  onPressed: _isExtractingColors ? null : _extractColorsFromLogo,
                  icon: Icons.palette,
                  label: _isExtractingColors ? 'Extracting...' : 'Extract Colors from Logo',
                  isLoading: _isExtractingColors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPickerRow extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ColorPickerRow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
          ],
        ),
      ),
    );
  }
}

class _StyleOption extends StatelessWidget {
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleOption({
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// Simple color picker dialog (keeping existing implementation)
class _SimpleColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final String label;

  const _SimpleColorPickerDialog({
    required this.initialColor,
    required this.label,
  });

  @override
  State<_SimpleColorPickerDialog> createState() => _SimpleColorPickerDialogState();
}

class _SimpleColorPickerDialogState extends State<_SimpleColorPickerDialog> {
  late Color _selectedColor;

  static const List<Color> _commonColors = [
    Colors.black,
    Colors.white,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select ${widget.label} Color',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _commonColors.map((color) {
                final isSelected = _selectedColor.value == color.value;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.blue : Colors.grey[300]!,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check, color: Colors.white, size: 24),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedColor),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
