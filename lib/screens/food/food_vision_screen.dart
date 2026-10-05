import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/food_vision_service.dart';
import '../../services/theme_service.dart';
import '../../modo_offline/conectividad_service.dart';

class FoodVisionScreen extends StatefulWidget {
  const FoodVisionScreen({super.key});

  @override
  State<FoodVisionScreen> createState() => _FoodVisionScreenState();
}

class _FoodVisionScreenState extends State<FoodVisionScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;

  @override
  void initState() {
    super.initState();
    _loadDefaultSampleImage();
  }

  Future<void> _loadDefaultSampleImage() async {
    try {
      final byteData = await rootBundle.load('assets/images/fotocomida.png');
      final bytes = byteData.buffer.asUint8List();
      if (mounted) {
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = 'FOTOcomida.png';
        });
        context.read<FoodVisionService>().clearLastAnalysis();
      }
    } catch (e) {
      debugPrint('No se pudo precargar la imagen de comida de muestra: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = file.name;
        });
        if (mounted) {
          context.read<FoodVisionService>().clearLastAnalysis();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cargar la imagen: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _analyzePhoto() async {
    if (_selectedImageBytes == null) return;

    final conectividad = context.read<ConectividadService>();
    if (!conectividad.estaConectado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: estás sin conexión a internet'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final service = context.read<FoodVisionService>();
    final result = await service.analyzeImage(_selectedImageBytes!, _selectedImageName ?? 'comida.jpg');

    if (result == null && mounted && service.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.errorMessage!),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final isDark = themeService.isDarkMode;
    final primaryGreen = isDark ? AppTheme.primaryGreenDark : AppTheme.primaryGreen;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final visionService = context.watch<FoodVisionService>();
    final isAnalyzing = visionService.isAnalyzing;
    final result = visionService.lastAnalysis;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Escanear Comida con IA'),
        backgroundColor: isDark ? AppTheme.darkSidebar : AppTheme.lightSidebar,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white10 : const Color(0x0A000000)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.camera_enhance_rounded, color: primaryGreen, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Visión Artificial Nutricional',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Toma o sube una foto de tu plato para estimar ingredientes y macronutrientes al instante.',
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Image Preview or Placeholder
              GestureDetector(
                onTap: isAnalyzing ? null : () => _showPickerSheet(context),
                child: Container(
                  height: 230,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _selectedImageBytes != null ? primaryGreen : (isDark ? Colors.white12 : Colors.black12),
                      width: 2,
                    ),
                  ),
                  child: _selectedImageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                              Positioned(
                                top: 12,
                                left: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.restaurant_rounded, size: 14, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text(
                                        'Foto de Plato Cargada',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text('Cambiar foto', style: TextStyle(color: Colors.white, fontSize: 11)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset('assets/images/fotocomida.png', fit: BoxFit.cover),
                              Container(
                                color: Colors.black.withValues(alpha: 0.25),
                              ),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined, size: 36, color: Colors.white),
                                      SizedBox(height: 6),
                                      Text(
                                        'Presiona para tomar foto o elegir de la galería',
                                        style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              if (_selectedImageBytes == null) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: const Text('Tomar Foto'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isAnalyzing ? null : _analyzePhoto,
                    icon: isAnalyzing
                        ? const SizedBox.shrink()
                        : const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                    label: isAnalyzing
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              ),
                              SizedBox(width: 12),
                              Text('Analizando plato con IA...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          )
                        : const Text(
                            'Analizar Plato con IA',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_rounded, size: 18),
                        label: const Text('Tomar Foto', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, size: 18),
                        label: const Text('Galería', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.all(12),
                      ),
                      tooltip: 'Restaurar foto de muestra',
                      onPressed: isAnalyzing ? null : _loadDefaultSampleImage,
                      icon: const Icon(Icons.restore_rounded, size: 18),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),

              // Analysis Results
              if (result != null) ...[
                Text(
                  'Resultados del Análisis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 12),

                // Macro Totals Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Estimación Calórica Total', style: TextStyle(fontSize: 12, color: textSecondary)),
                              const SizedBox(height: 2),
                              Text(
                                '${result.totalCalorias.toStringAsFixed(0)} kcal',
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryGreen),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: primaryGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Confianza: ${result.confianza.toUpperCase()}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryGreen),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNutrientBadge('Proteínas', '${result.totalProteinas.toStringAsFixed(1)}g', AppTheme.accentCoral),
                          _buildNutrientBadge('Carbohidratos', '${result.totalCarbs.toStringAsFixed(1)}g', AppTheme.accentOrange),
                          _buildNutrientBadge('Grasas', '${result.totalGrasas.toStringAsFixed(1)}g', AppTheme.accentBlue),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Clinical Goal Evaluation Card
                if (result.evalMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C251D) : const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: primaryGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.insights_rounded, color: primaryGreen, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Evaluación según tu Meta Diaria',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                result.evalMessage!,
                                style: TextStyle(fontSize: 12, color: textSecondary, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Detected Food List
                if (result.alimentos.isNotEmpty) ...[
                  Text('Alimentos Identificados en la Foto:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                  const SizedBox(height: 8),
                  ...result.alimentos.map((f) => Card(
                        color: cardBg,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen.withValues(alpha: 0.15),
                            child: Icon(Icons.restaurant_rounded, color: primaryGreen, size: 18),
                          ),
                          title: Text(f.nombre, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textPrimary)),
                          subtitle: Text('Porción aprox: ${f.porcionG.toStringAsFixed(0)}g | P: ${f.proteinasG}g | C: ${f.carbohidratosG}g',
                              style: TextStyle(fontSize: 11, color: textSecondary)),
                          trailing: Text('${f.calorias.toStringAsFixed(0)} kcal',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryGreen)),
                        ),
                      )),
                ],

                const SizedBox(height: 12),

                // Disclaimer
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Estimación aproximada por visión artificial. Diseñada como apoyo al seguimiento.',
                          style: TextStyle(fontSize: 11, color: textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _showPickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tomar foto con la cámara'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('Restaurar foto de muestra de comida'),
              onTap: () {
                Navigator.pop(ctx);
                _loadDefaultSampleImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
