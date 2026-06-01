import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const kBgColor = Color(0xFFF5F7FA); // Light grey page background
const kWhite = Color(0xFFFFFFFF);
const kNavy = Color(0xFF0A1628); // Dark navy — headings, dark cards
const kTeal = Color(0xFF0B9ED9); // Primary teal — buttons, accents, active nav
const kTealLight = Color(0xFFE0F4FB); // Light teal — chip bg, info cards
const kRed = Color(0xFFE53935); // Disease detected — Pneumonia, Cancer
const kGreen = Color(0xFF00897B); // Normal / healthy
const kOrange = Color(0xFFF57C00); // Warning states
const kTextDark = Color(0xFF1A2340); // Body text
const kTextMuted = Color(0xFF6B7A99); // Muted/secondary text
const kBorder = Color(0xFFDDE3EE); // Card borders
const kCardBg = Color(0xFFFFFFFF); // Card backgrounds

const kRadius = 16.0; // Card border radius
const kRadiusSm = 8.0; // Chip/badge border radius
const kPadding = 20.0; // Horizontal page padding

const kCardShadow = BoxShadow(
  color: Color(0x0F000000),
  blurRadius: 12,
  offset: Offset(0, 4),
);

// NOTE on the backend URL:
//   - Android EMULATOR: use 'http://10.0.2.2:5000' (alias for your PC's localhost)
//   - PHYSICAL DEVICE : use your PC's LAN IP, e.g. 'http://172.20.104.136:5000'
//     (phone and PC must be on the same Wi-Fi; run `ipconfig` to re-check the IP)
const String kBaseUrl = 'http://172.20.104.136:5000';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class ScanRecord {
  final String scanId;
  final String patientName;
  final String patientId;
  final DateTime date;
  final String disease; // e.g. "Pneumonia"
  final double confidence; // e.g. 84.5
  final String imagePath; // local file path
  final bool isProcessing;

  ScanRecord({
    required this.scanId,
    required this.patientName,
    required this.patientId,
    required this.date,
    required this.disease,
    required this.confidence,
    required this.imagePath,
    this.isProcessing = false,
  });

  bool get isHealthy => disease == 'Normal';
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HISTORY STATE
// ─────────────────────────────────────────────────────────────────────────────

final ValueNotifier<List<ScanRecord>> historyNotifier =
    ValueNotifier<List<ScanRecord>>([
  ScanRecord(
    scanId: 'Scan_ID_8812',
    patientName: 'John Doe',
    patientId: '#88219',
    date: DateTime(2023, 10, 24),
    disease: 'Normal',
    confidence: 98.2,
    imagePath: '',
  ),
  ScanRecord(
    scanId: 'Scan_ID_7741',
    patientName: 'Sarah Jenkins',
    patientId: '#77412',
    date: DateTime(2023, 10, 22),
    disease: 'Pneumonia',
    confidence: 84.5,
    imagePath: '',
  ),
  ScanRecord(
    scanId: 'Scan_ID_6109',
    patientName: 'Michael Smith',
    patientId: '#61099',
    date: DateTime(2023, 10, 19),
    disease: 'Normal',
    confidence: 99.1,
    imagePath: '',
  ),
  ScanRecord(
    scanId: 'Scan_ID_9021',
    patientName: 'Elena Rodriguez',
    patientId: '#90214',
    date: DateTime(2023, 10, 15),
    disease: 'Normal',
    confidence: 95.6,
    imagePath: '',
  ),
]);

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String formatDate(DateTime date) {
  // Returns e.g. "OCT 24, 2023"
  const months = [
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC'
  ];
  return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
}

PreferredSizeWidget pulmaAppBar() {
  return AppBar(
    backgroundColor: kWhite,
    elevation: 0,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: const Color(0xFFEEF0F5)),
    ),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: kTealLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.grid_view_rounded, color: kTeal, size: 18),
        ),
        const SizedBox(width: 8),
        const Text(
          'PULMA AI',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: kNavy,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
    actions: const [
      Padding(
        padding: EdgeInsets.only(right: 16),
        child: Icon(Icons.account_circle_outlined, color: kTextMuted, size: 28),
      ),
    ],
  );
}

Widget _infoCard(IconData icon, String title, String body) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kTealLight,
      borderRadius: BorderRadius.circular(kRadius),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: kTeal, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: kNavy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// APP ENTRY
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  runApp(const PulmaApp());
}

class PulmaApp extends StatelessWidget {
  const PulmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PULMA AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kTeal),
        scaffoldBackgroundColor: kBgColor,
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SHELL — Bottom Navigation
// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  List<Widget> get _screens => [
        HomeScreen(onNavigateToScan: () => setState(() => _currentIndex = 1)),
        const ScanScreen(),
        const HistoryScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: kWhite,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(0, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.document_scanner_outlined, 'Scan'),
              _navItem(2, Icons.history_rounded, 'History'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final bool active = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(active ? 10 : 8),
            decoration: BoxDecoration(
              color: active ? kTeal : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: active ? kWhite : kTextMuted, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? kTeal : kTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 1 — HOME
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToScan;
  const HomeScreen({super.key, required this.onNavigateToScan});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: pulmaAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _heroHeader(),
              _lungBanner(),
              const SizedBox(height: 24),
              _diagnosticScanCard(),
              const SizedBox(height: 16),
              _currentAnalysisCard(),
              const SizedBox(height: 16),
              _modelArchitectureCard(),
              const SizedBox(height: 24),
              _explainabilitySection(),
              const SizedBox(height: 24),
              _symptomChips(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // Section A — Hero Header
  Widget _heroHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: kTealLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kTeal, width: 1),
                ),
                child: const Text(
                  'Visionary Clinical AI',
                  style: TextStyle(
                    color: kTeal,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Respiratory\nDisease\nDetection AI',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: kNavy,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'High-precision AI-Powered Chest X-ray Analysis. Leveraging deep learning to identify pulmonary conditions with 98.4% diagnostic accuracy.',
                style: TextStyle(fontSize: 13, color: kTextMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: widget.onNavigateToScan,
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload Chest X-ray'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: kWhite,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextDark,
                  side: const BorderSide(color: kBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('View Documentation'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Section B — Lung Image Banner
  Widget _lungBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      height: 200,
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          const Center(
            child: Icon(Icons.air, size: 80, color: kTeal),
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '98.4%',
                style: TextStyle(
                  color: kTeal,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section C — Diagnostic Scan Card
  Widget _diagnosticScanCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        children: [
          const Icon(Icons.image_search_rounded, size: 36, color: kTeal),
          const SizedBox(height: 12),
          const Text(
            'Diagnostic Scan',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Drag and drop your DICOM or JPEG X-ray files here for immediate neural network classification.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: kTextMuted),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _formatChip('DICOM'),
              const SizedBox(width: 8),
              _formatChip('JPEG'),
              const SizedBox(width: 8),
              _formatChip('PNG'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formatChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kTealLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kTeal,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Section D — Current Analysis Result Card
  Widget _currentAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT ANALYSIS',
            style: TextStyle(
              fontSize: 11,
              color: kTextMuted,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: kRed, size: 20),
              SizedBox(width: 8),
              Text(
                'Pneumonia',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: kRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Text('Confidence',
                  style: TextStyle(fontSize: 13, color: kTextMuted)),
              SizedBox(width: 6),
              Text(
                '96%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0.96,
              minHeight: 6,
              backgroundColor: kBorder,
              valueColor: AlwaysStoppedAnimation<Color>(kRed),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.shield_outlined, size: 14, color: kTextMuted),
              SizedBox(width: 6),
              Text(
                'Status: Urgent Review',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Section E — Model Architecture Card
  Widget _modelArchitectureCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Model Architecture',
            style: TextStyle(
              fontSize: 16,
              color: kWhite,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _archRow('Accuracy', '98.4%', valueColor: kTeal, valueBold: true),
          const Divider(color: Colors.white12, height: 24),
          _archRow('Backbone', 'DenseNet-121', valueColor: kWhite),
          const Divider(color: Colors.white12, height: 24),
          _archRow('Precision', '0.97', valueColor: kWhite),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _miniBar(16, Colors.white30),
              _miniBar(16, Colors.white30),
              _miniBar(32, kTeal),
              _miniBar(16, Colors.white30),
              _miniBar(16, Colors.white30),
            ],
          ),
        ],
      ),
    );
  }

  Widget _archRow(String label, String value,
      {required Color valueColor, bool valueBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: valueBold ? 18 : 14,
            fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _miniBar(double height, Color color) {
    return Container(
      height: height,
      width: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Section F — AI Explainability Section
  Widget _explainabilitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Explainability Analysis',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kNavy,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 13, color: kTextMuted),
            children: [
              TextSpan(
                text:
                    'Visualizing Grad-CAM attention regions highlighting pulmonary infiltration. ',
              ),
              TextSpan(
                text: 'Detailed Report ↗',
                style: TextStyle(
                  color: kTeal,
                  decoration: TextDecoration.underline,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'RAW SCAN',
          style: TextStyle(
            fontSize: 10,
            color: kTextMuted,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: kNavy,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.medical_services_outlined,
                    size: 48, color: Colors.white38),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _overlayChip('RAW SCAN', Colors.white24),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Original X-ray',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
        const SizedBox(height: 20),
        Container(
          height: 160,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kNavy, Color(0xFFBF360C)],
            ),
          ),
          child: Stack(
            children: [
              const Center(
                child: Icon(Icons.blur_on, size: 48, color: Colors.orange),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _overlayChip(
                    'GRAD-CAM ACTIVATION', Colors.orange.withOpacity(0.8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Text('AI Heatmap Overlay (Heat Regions)',
            style: TextStyle(fontSize: 12, color: kTextMuted)),
      ],
    );
  }

  Widget _overlayChip(String label, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kWhite,
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  // Section G — Symptom Chips
  Widget _symptomChips() {
    return Wrap(
      spacing: 8,
      children: [
        _symptomChip('Shortness of Breath'),
        _symptomChip('Persistent Cough'),
      ],
    );
  }

  Widget _symptomChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: kTealLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kTeal,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 2 — SCAN
// ─────────────────────────────────────────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _selectedImage;
  bool _isLoading = false;
  bool _isGradcamLoading = false;
  Map<String, dynamic>? _result;
  String? _gradcamBase64;
  String? _errorMessage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? picked =
        await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _result = null;
        _gradcamBase64 = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$kBaseUrl/predict'));
      request.files.add(
          await http.MultipartFile.fromPath('file', _selectedImage!.path));
      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Request timed out'),
      );
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['status'] == 'success') {
        setState(() {
          _result = data;
        });
        final newRecord = ScanRecord(
          scanId: 'Scan_ID_${DateTime.now().millisecondsSinceEpoch % 10000}',
          patientName: 'New Patient',
          patientId: '#${(10000 + historyNotifier.value.length)}',
          date: DateTime.now(),
          disease: data['disease'] as String,
          confidence: (data['confidence'] as num).toDouble(),
          imagePath: _selectedImage!.path,
        );
        historyNotifier.value = [newRecord, ...historyNotifier.value];
      } else {
        setState(() {
          _errorMessage = (data['message'] as String?) ?? 'Analysis failed.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not reach server. Is Flask running?';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGradcam() async {
    if (_selectedImage == null) return;
    setState(() {
      _isGradcamLoading = true;
    });
    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$kBaseUrl/gradcam'));
      request.files.add(
          await http.MultipartFile.fromPath('file', _selectedImage!.path));
      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Gradcam timed out'),
      );
      final body = await response.stream.bytesToString();
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (data['status'] == 'success') {
        setState(() {
          _gradcamBase64 = data['gradcam_image'] as String?;
        });
      }
    } catch (e) {
      // silently fail gradcam
    } finally {
      setState(() {
        _isGradcamLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: pulmaAppBar(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Section A — Page Header
              const Text(
                'Respiratory Scan',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: kNavy,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'AI-powered diagnostic analysis for chest imaging.',
                style: TextStyle(fontSize: 13, color: kTextMuted),
              ),
              const SizedBox(height: 24),
              _uploadZone(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                _errorBanner(),
              ],
              const SizedBox(height: 24),
              _recentUploads(),
              const SizedBox(height: 24),
              _resultCard(),
              _gradcamCard(),
              _infoCard(
                Icons.info_outline,
                'Image Requirements',
                'For maximum accuracy, ensure images are not cropped and patient metadata is preserved in DICOM headers.',
              ),
              _infoCard(
                Icons.verified_user_outlined,
                'Privacy & Compliance',
                'All uploads are end-to-end encrypted and HIPAA compliant. Processing is performed locally when possible.',
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  // Section B — Upload Zone Card
  Widget _uploadZone() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1.5),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: kTealLight,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(Icons.fit_screen_outlined, size: 36, color: kTeal),
          ),
          const SizedBox(height: 16),
          const Text(
            'Upload Chest X-Ray',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _uploadChip('DICOM'),
              const SizedBox(width: 8),
              _uploadChip('JPEG'),
              const SizedBox(width: 8),
              _uploadChip('MAX 25MB'),
            ],
          ),
          const SizedBox(height: 20),
          if (_selectedImage == null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon:
                    const Icon(Icons.add_photo_alternate_outlined, size: 18),
                label: const Text(
                  'SELECT CLINICAL IMAGE',
                  style: TextStyle(letterSpacing: 1),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: kWhite,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            )
          else ...[
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    fit: BoxFit.cover,
                    height: 180,
                    width: double.infinity,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedImage = null;
                        _result = null;
                        _gradcamBase64 = null;
                        _errorMessage = null;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child:
                          const Icon(Icons.close, color: kWhite, size: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _analyzeImage,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(kWhite),
                        ),
                      )
                    : const Icon(Icons.search, size: 18),
                label: Text(_isLoading ? 'Analyzing...' : 'ANALYZE X-RAY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  foregroundColor: kWhite,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Ensure images are clear, front-facing, and captured in high-resolution for optimal AI precision.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ],
      ),
    );
  }

  Widget _uploadChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: kTealLight,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: kTeal,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: kRed, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: kRed, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // Section C — Recent Uploads
  Widget _recentUploads() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Uploads',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kNavy,
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(foregroundColor: kTeal),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ValueListenableBuilder<List<ScanRecord>>(
          valueListenable: historyNotifier,
          builder: (context, records, _) {
            return SizedBox(
              height: 145,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: records.length,
                itemBuilder: (context, i) {
                  final r = records[i];
                  return Container(
                    width: 120,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: kNavy,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        if (r.imagePath.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(r.imagePath),
                              fit: BoxFit.cover,
                              width: 120,
                              height: 145,
                            ),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black54],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Text(
                            r.scanId,
                            style: const TextStyle(
                              color: kWhite,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 26,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: r.isHealthy
                                  ? kGreen.withOpacity(0.8)
                                  : kRed.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.isHealthy ? 'Complete' : 'Processing',
                              style:
                                  const TextStyle(color: kWhite, fontSize: 9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  // Section D — Result Card
  Widget _resultCard() {
    final bool visible = _result != null;
    if (!visible) {
      return const SizedBox.shrink();
    }

    final String disease = (_result!['disease'] as String?) ?? 'Unknown';
    final double confidence =
        (_result!['confidence'] as num?)?.toDouble() ?? 0.0;
    final bool isNormal = disease == 'Normal';
    final Map<String, dynamic> probs =
        (_result!['all_probabilities'] as Map<String, dynamic>?) ?? {};

    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kWhite,
          border: Border.all(color: kBorder),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [kCardShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DIAGNOSIS RESULT',
                      style: TextStyle(
                        fontSize: 11,
                        color: kTextMuted,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      disease,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isNormal ? kGreen : kRed,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: confidence > 90
                        ? kGreen.withOpacity(0.1)
                        : kOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$confidence%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: confidence > 90 ? kGreen : kOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'All Probabilities',
              style: TextStyle(
                fontSize: 12,
                color: kTextMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...probs.entries.map((entry) {
              final double p = (entry.value as num).toDouble();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style:
                            const TextStyle(fontSize: 12, color: kTextDark),
                      ),
                      Text(
                        '$p%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kTextDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: p / 100,
                      minHeight: 5,
                      backgroundColor: kBorder,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(kTeal),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            }),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGradcamLoading ? null : _fetchGradcam,
                icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
                label: Text(
                  _isGradcamLoading
                      ? 'Loading Heatmap...'
                      : 'Show AI Heatmap',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTeal,
                  side: const BorderSide(color: kTeal),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section E — Grad-CAM Result
  Widget _gradcamCard() {
    if (_gradcamBase64 == null) {
      return const SizedBox.shrink();
    }
    final Uint8List bytes = base64Decode(_gradcamBase64!.split(',').last);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Explainability — Grad-CAM',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kNavy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Red/orange regions indicate disease-affected areas.',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN 3 — HISTORY
// ─────────────────────────────────────────────────────────────────────────────

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgColor,
      appBar: pulmaAppBar(),
      body: SingleChildScrollView(
        child: Column(
        children: [
          // Section A — Page Header
          Padding(
            padding: const EdgeInsets.only(
                left: kPadding, right: kPadding, top: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Diagnostic History',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: kNavy,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'View and manage clinical respiratory reports.',
                        style: TextStyle(fontSize: 13, color: kTextMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text(
                    'Download\nAll',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kNavy,
                    foregroundColor: kWhite,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Section B — Search Bar
          Padding(
            padding: const EdgeInsets.only(
                left: kPadding, right: kPadding, top: 16),
            child: Container(
              decoration: BoxDecoration(
                color: kWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, color: kTextMuted),
                  suffixIcon: Icon(Icons.tune, color: kTextMuted),
                  hintText: 'Filter by Patient ID, date, or diagnosis...',
                  hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
            ),
          ),
          // Section C — Records List
          ValueListenableBuilder<List<ScanRecord>>(
            valueListenable: historyNotifier,
            builder: (context, records, _) {
              final filtered = _query.isEmpty
                  ? records
                  : records
                      .where((r) =>
                          r.patientName.toLowerCase().contains(_query) ||
                          r.patientId.toLowerCase().contains(_query) ||
                          r.disease.toLowerCase().contains(_query) ||
                          r.scanId.toLowerCase().contains(_query))
                      .toList();
              return Padding(
                padding: const EdgeInsets.only(
                    left: kPadding, right: kPadding, top: 16),
                child: Column(
                  children: [
                    for (final record in filtered) _buildRecordCard(record),
                  ],
                ),
              );
            },
          ),
          // Section D — Load More Button
          Padding(
            padding: const EdgeInsets.only(
                left: kPadding, right: kPadding, top: 4, bottom: 100),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Load Previous Reports'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextDark,
                  side: const BorderSide(color: kBorder),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(ScanRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: const [kCardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PATIENT ID: ${record.patientId}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: kTextMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      record.patientName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: kNavy,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kTealLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formatDate(record.date),
                  style: const TextStyle(
                    fontSize: 11,
                    color: kTeal,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // X-ray image preview
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: record.imagePath.isNotEmpty
                    ? Image.file(
                        File(record.imagePath),
                        height: 150,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : Container(
                        height: 150,
                        width: double.infinity,
                        color: kNavy,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.white24,
                            size: 40,
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color:
                        (record.isHealthy ? kGreen : kRed).withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        record.isHealthy
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: kWhite,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        record.disease,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kWhite,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Confidence bar + chevron
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Confidence',
                      style: TextStyle(fontSize: 11, color: kTextMuted),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: record.confidence / 100,
                              minHeight: 7,
                              backgroundColor: kBorder,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                record.confidence >= 90
                                    ? kGreen
                                    : record.confidence >= 70
                                        ? kOrange
                                        : kRed,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${record.confidence}%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kTextDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorder, width: 1.5),
                ),
                child: const Icon(Icons.chevron_right,
                    color: kTextMuted, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
