import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/user_settings.dart';
import '../../data/repositories/settings_repo.dart' show settingsRepoProvider, SettingsRepo;
import '../../data/repositories/google_drive_repo.dart';
import '../../data/repositories/payment_repo.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'google_drive_folder_dialog.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _companyEmailController = TextEditingController();
  final _companyPhoneController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _companyCityController = TextEditingController();
  final _companyProvinceController = TextEditingController();
  final _companyPostalController = TextEditingController();
  final _companyCountryController = TextEditingController();
  final _companyTaxNumberController = TextEditingController();
  final _companyWebsiteController = TextEditingController();
  final _defaultTaxRateController = TextEditingController();
  final _defaultPaymentTermsController = TextEditingController();
  final _currencyController = TextEditingController();
  final _defaultInvoiceNotesController = TextEditingController();
  final _invoiceNumberPrefixController = TextEditingController();

  String? _logoUrl;
  bool _isSaving = false;
  bool _isUploadingLogo = false;
  bool _isConnectingDrive = false;
  bool _isDisconnectingDrive = false;
  Map<String, dynamic>? _driveStatus;
  bool _isConnectingStripe = false;
  Map<String, dynamic>? _stripeStatus;
  Map<String, dynamic>? _paymentFees;
  bool _enableAutoReminders = true;
  int _reminderDaysBeforeDue = 3;
  int _reminderDaysAfterDue = 7;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _loadDriveStatus();
      _loadStripeStatus();
      _loadPaymentFees();
      
      // Check if returning from Stripe onboarding
      final uri = Uri.base;
      if (uri.queryParameters.containsKey('connected') || uri.queryParameters.containsKey('refresh')) {
        // Switch to payments tab
        _tabController.animateTo(2);
        // Reload Stripe status after a delay to allow Stripe webhook to process
        Future.delayed(const Duration(seconds: 2), () {
          _loadStripeStatus();
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _companyNameController.dispose();
    _companyEmailController.dispose();
    _companyPhoneController.dispose();
    _companyAddressController.dispose();
    _companyCityController.dispose();
    _companyProvinceController.dispose();
    _companyPostalController.dispose();
    _companyCountryController.dispose();
    _companyTaxNumberController.dispose();
    _companyWebsiteController.dispose();
    _defaultTaxRateController.dispose();
    _defaultPaymentTermsController.dispose();
    _currencyController.dispose();
    _defaultInvoiceNotesController.dispose();
    _invoiceNumberPrefixController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final repo = ref.read(settingsRepoProvider);
      final settings = await repo.getSettings();
      
      setState(() {
        _companyNameController.text = settings.companyName ?? '';
        _companyEmailController.text = settings.companyEmail ?? '';
        _companyPhoneController.text = settings.companyPhone ?? '';
        _companyAddressController.text = settings.companyAddress ?? '';
        _companyCityController.text = settings.companyCity ?? '';
        _companyProvinceController.text = settings.companyProvince ?? '';
        _companyPostalController.text = settings.companyPostal ?? '';
        _companyCountryController.text = settings.companyCountry ?? '';
        _companyTaxNumberController.text = settings.companyTaxNumber ?? '';
        _companyWebsiteController.text = settings.companyWebsite ?? '';
        _logoUrl = settings.companyLogoUrl;
        _enableAutoReminders = settings.enableAutoReminders ?? true;
        _reminderDaysBeforeDue = settings.reminderDaysBeforeDue ?? 3;
        _reminderDaysAfterDue = settings.reminderDaysAfterDue ?? 7;
        _defaultTaxRateController.text = (settings.defaultTaxRate ?? 0).toString();
        _defaultPaymentTermsController.text = settings.defaultPaymentTerms ?? '';
        _currencyController.text = settings.currency ?? 'USD';
        _defaultInvoiceNotesController.text = settings.defaultInvoiceNotes ?? '';
        _invoiceNumberPrefixController.text = settings.invoiceNumberPrefix ?? 'INV';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading settings: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _isUploadingLogo = true;
      });

      final repo = ref.read(settingsRepoProvider);
      final result = await repo.uploadLogo(image);
      
      setState(() {
        _logoUrl = result['logoUrl'] as String?;
        _isUploadingLogo = false;
      });

      // Reload settings to get updated logo URL
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo uploaded successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingLogo = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading logo: $e')),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ref.read(settingsRepoProvider);
      await repo.updateSettings({
        'companyName': _companyNameController.text.trim().isEmpty 
            ? null 
            : _companyNameController.text.trim(),
        'companyEmail': _companyEmailController.text.trim().isEmpty 
            ? null 
            : _companyEmailController.text.trim(),
        'companyPhone': _companyPhoneController.text.trim().isEmpty 
            ? null 
            : _companyPhoneController.text.trim(),
        'companyAddress': _companyAddressController.text.trim().isEmpty 
            ? null 
            : _companyAddressController.text.trim(),
        'companyCity': _companyCityController.text.trim().isEmpty 
            ? null 
            : _companyCityController.text.trim(),
        'companyProvince': _companyProvinceController.text.trim().isEmpty 
            ? null 
            : _companyProvinceController.text.trim(),
        'companyPostal': _companyPostalController.text.trim().isEmpty 
            ? null 
            : _companyPostalController.text.trim(),
        'companyCountry': _companyCountryController.text.trim().isEmpty 
            ? null 
            : _companyCountryController.text.trim(),
        'companyTaxNumber': _companyTaxNumberController.text.trim().isEmpty 
            ? null 
            : _companyTaxNumberController.text.trim(),
        'companyWebsite': _companyWebsiteController.text.trim().isEmpty 
            ? null 
            : _companyWebsiteController.text.trim(),
        'enableAutoReminders': _enableAutoReminders,
        'reminderDaysBeforeDue': _reminderDaysBeforeDue,
        'reminderDaysAfterDue': _reminderDaysAfterDue,
        'defaultTaxRate': _defaultTaxRateController.text.trim().isEmpty 
            ? null 
            : double.tryParse(_defaultTaxRateController.text.trim()),
        'defaultPaymentTerms': _defaultPaymentTermsController.text.trim().isEmpty 
            ? null 
            : _defaultPaymentTermsController.text.trim(),
        'currency': _currencyController.text.trim().isEmpty 
            ? 'USD' 
            : _currencyController.text.trim().toUpperCase(),
        'defaultInvoiceNotes': _defaultInvoiceNotesController.text.trim().isEmpty 
            ? null 
            : _defaultInvoiceNotesController.text.trim(),
        'invoiceNumberPrefix': _invoiceNumberPrefixController.text.trim().isEmpty 
            ? 'INV' 
            : _invoiceNumberPrefixController.text.trim().toUpperCase(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _loadPaymentFees() async {
    try {
      final repo = ref.read(paymentRepoProvider);
      final fees = await repo.getPaymentFees();
      if (mounted) {
        setState(() {
          _paymentFees = fees;
        });
      }
    } catch (e) {
      debugPrint('Error loading payment fees: $e');
    }
  }

  Future<void> _loadStripeStatus() async {
    try {
      final repo = ref.read(paymentRepoProvider);
      final statusData = await repo.getConnectStatus();
      if (mounted) {
        setState(() {
          _stripeStatus = statusData;
        });
      }
    } catch (e) {
      debugPrint('Error loading Stripe status: $e');
      if (mounted) {
        setState(() {
          _stripeStatus = {'success': false, 'status': null};
        });
      }
    }
  }

  Future<void> _connectStripeAccount() async {
    setState(() {
      _isConnectingStripe = true;
    });

    try {
      final repo = ref.read(paymentRepoProvider);
      
      // First create account
      final result = await repo.createConnectAccount();
      final onboardingUrl = result['onboardingUrl'] as String;

      // Reload status
      await _loadStripeStatus();

      // Launch onboarding URL
      final uri = Uri.parse(onboardingUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch browser');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete Stripe setup in your browser. Return here when done.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error connecting Stripe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting Stripe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingStripe = false;
        });
      }
    }
  }

  Future<void> _continueStripeOnboarding() async {
    setState(() {
      _isConnectingStripe = true;
    });

    try {
      final repo = ref.read(paymentRepoProvider);
      final result = await repo.getOnboardingLink();
      final onboardingUrl = result['onboardingUrl'] as String;

      // Launch onboarding URL
      final uri = Uri.parse(onboardingUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch browser');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Complete Stripe setup in your browser. Return here when done.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting onboarding link: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingStripe = false;
        });
      }
    }
  }

  Future<void> _loadDriveStatus() async {
    try {
      final repo = ref.read(googleDriveRepoProvider);
      final status = await repo.getStatus();
      setState(() {
        _driveStatus = status;
      });
    } catch (e) {
      debugPrint('Error loading Drive status: $e');
      setState(() {
        _driveStatus = {'connected': false};
      });
    }
  }

  Future<void> _connectGoogleDrive() async {
    try {
      setState(() {
        _isConnectingDrive = true;
      });

      // Verify user is authenticated
      final apiClient = ref.read(apiClientProvider);
      final token = await apiClient.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('You must be logged in to connect Google Drive. Please log out and log back in.');
      }

      // Get auth URL from backend
      final driveRepo = ref.read(googleDriveRepoProvider);
      final authUrl = await driveRepo.getAuthUrl();

      // Launch browser for OAuth
      final uri = Uri.parse(authUrl);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch browser');
      }

      // Show dialog to get authorization code OR refresh token from user
      final input = await _showCodeOrTokenDialog();
      if (input == null || input.isEmpty) {
        return;
      }

      // Determine whether user pasted a refresh token (starts with '1//')
      String refreshToken;
      if (input.startsWith('1//')) {
        // User pasted a refresh token directly from the success page
        refreshToken = input;
      } else {
        // Assume input is a short authorization code; exchange it
        final exchangeResult = await driveRepo.exchangeCode(input);
        refreshToken = exchangeResult['refreshToken'] as String;
      }

      // Show folder name dialog
      final settingsRepo = ref.read(settingsRepoProvider);
      final settings = await settingsRepo.getSettings();

      String? folderName = settings.companyName != null
          ? '${settings.companyName} Invoices'
          : null;

      folderName = await showDialog<String>(
        context: context,
        builder: (context) => GoogleDriveFolderDialog(
          defaultFolderName: folderName,
        ),
      );

      if (folderName == null) {
        return;
      }

      // Setup folder
      final setupResult = await driveRepo.setupFolder(
        refreshToken: refreshToken,
        folderName: folderName,
      );

      // Reload settings and status
      await _loadSettings();
      await _loadDriveStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(setupResult['message'] as String? ?? 'Google Drive connected!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error connecting Google Drive: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error connecting Google Drive: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingDrive = false;
        });
      }
    }
  }

  Future<String?> _showCodeOrTokenDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Paste Code or Refresh Token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'After approving in the browser:\n'
              '• If you see a page with "refreshToken", copy that long value (starts with 1//) and paste it here.\n'
              '• If you were shown a short authorization code instead, paste that code here.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Authorization Code or Refresh Token',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    ).then((value) {
      controller.dispose();
      return value;
    });
  }

  Future<void> _disconnectGoogleDrive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Drive'),
        content: const Text(
          'Are you sure you want to disconnect Google Drive? Your invoices will no longer be automatically saved to Drive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isDisconnectingDrive = true;
      });

      final driveRepo = ref.read(googleDriveRepoProvider);
      await driveRepo.disconnect();

      await _loadDriveStatus();
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Drive disconnected'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error disconnecting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDisconnectingDrive = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final repo = ref.read(settingsRepoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: canPop,
        leading: canPop ? const BackButton() : null,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'Business Info'),
            Tab(icon: Icon(Icons.cloud), text: 'Google Drive'),
            Tab(icon: Icon(Icons.payment), text: 'Payments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Business Information Tab
          _buildBusinessInfoTab(ref.read(settingsRepoProvider)),
          // Google Drive Tab
          _buildGoogleDriveTab(),
          // Payments Tab
          _buildPaymentsTab(),
        ],
      ),
    );
  }

  Widget _buildBusinessInfoTab(SettingsRepo repo) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Logo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_logoUrl != null)
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              repo.getLogoUrl(_logoUrl) ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.image, size: 50);
                              },
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.image, size: 50),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingLogo ? null : _pickAndUploadLogo,
                          icon: _isUploadingLogo
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload),
                          label: Text(_isUploadingLogo ? 'Uploading...' : 'Upload Logo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Logo will appear on invoices and estimates. Recommended: 200x200px, PNG or JPG.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Company Information
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyNameController,
                    decoration: const InputDecoration(
                      labelText: 'Company Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Company name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyWebsiteController,
                    decoration: const InputDecoration(
                      labelText: 'Website',
                      border: OutlineInputBorder(),
                      prefixText: 'https://',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Address
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Address',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyAddressController,
                    decoration: const InputDecoration(
                      labelText: 'Street Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _companyCityController,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _companyProvinceController,
                          decoration: const InputDecoration(
                            labelText: 'Province/State',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _companyPostalController,
                          decoration: const InputDecoration(
                            labelText: 'Postal/ZIP Code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _companyCountryController,
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Additional Information
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Additional Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _companyTaxNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Tax ID / GST Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Invoice Defaults Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Invoice Defaults',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'These settings will be used as defaults when creating new invoices.',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _defaultTaxRateController,
                          decoration: const InputDecoration(
                            labelText: 'Default Tax Rate (%)',
                            hintText: '0.0',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final rate = double.tryParse(value);
                              if (rate == null || rate < 0 || rate > 100) {
                                return 'Must be between 0 and 100';
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _defaultPaymentTermsController,
                          decoration: const InputDecoration(
                            labelText: 'Default Payment Terms',
                            hintText: 'Net 30, Due on receipt',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _currencyController,
                          decoration: const InputDecoration(
                            labelText: 'Currency',
                            hintText: 'USD',
                            border: OutlineInputBorder(),
                            helperText: 'ISO code (e.g., USD, CAD, EUR)',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 3,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _invoiceNumberPrefixController,
                          decoration: const InputDecoration(
                            labelText: 'Invoice Number Prefix',
                            hintText: 'INV',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _defaultInvoiceNotesController,
                    decoration: const InputDecoration(
                      labelText: 'Default Invoice Notes / Terms & Conditions',
                      hintText: 'Payment is due within 30 days...',
                      border: OutlineInputBorder(),
                      helperText: 'This text will appear on all new invoices',
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Settings', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGoogleDriveTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Google Drive Backup',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Automatically save your invoices and photos to your Google Drive for secure backup and easy access.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                if (_driveStatus == null) ...[
                  // Loading state
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (_driveStatus!['connected'] == true) ...[
                  // Connected state
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Connected',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                        if (_driveStatus!['folderName'] != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Folder: ${_driveStatus!['folderName']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                        if (_driveStatus!['folderLink'] != null) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final link = _driveStatus!['folderLink'] as String;
                                final uri = Uri.parse(link);
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              },
                              icon: const Icon(Icons.open_in_new, size: 18),
                              label: const Text('Open in Google Drive'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isDisconnectingDrive
                          ? null
                          : _disconnectGoogleDrive,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isDisconnectingDrive
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Disconnect Google Drive'),
                    ),
                  ),
                ] else ...[
                  // Not connected state
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConnectingDrive
                          ? null
                          : _connectGoogleDrive,
                      icon: _isConnectingDrive
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload),
                      label: Text(_isConnectingDrive
                          ? 'Connecting...'
                          : 'Connect Google Drive'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stripe Payment Settings Section
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.payment,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Payment Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Connect your Stripe account to accept payments from customers. Payments go directly to your bank account.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                
                // Payment Fees Disclosure (ALWAYS SHOWN)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 20, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Processing Fees',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_paymentFees != null) ...[
                        Text(
                          '• Credit/Debit Cards: ${_paymentFees!['cardFee'] ?? '2.9% + \$0.30 per transaction'}',
                          style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Bank Transfers (ACH): ${_paymentFees!['achFee'] ?? '0.8% per transaction (max \$5)'}',
                          style: TextStyle(fontSize: 14, color: Colors.blue.shade900),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _paymentFees!['description'] ?? 'Fees are automatically deducted from each payment.',
                          style: TextStyle(fontSize: 13, color: Colors.blue.shade800),
                        ),
                      ] else ...[
                        const Text(
                          '• Credit/Debit Cards: 2.9% + \$0.30 per transaction',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• Bank Transfers (ACH): 0.8% per transaction (max \$5)',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Fees are automatically deducted from each payment before funds are deposited to your bank account.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_stripeStatus != null && _stripeStatus!['status'] != null) ...[
                  // Connected state
                  Builder(
                    builder: (context) {
                      final status = _stripeStatus!['status'] as Map<String, dynamic>;
                      final isActive = status['chargesEnabled'] == true && status['detailsSubmitted'] == true;
                      
                      return Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isActive ? Colors.green.shade200 : Colors.orange.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isActive ? Icons.check_circle : Icons.warning_amber,
                                  color: isActive ? Colors.green : Colors.orange,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    isActive
                                        ? 'Stripe account connected and ready'
                                        : 'Stripe account setup incomplete',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isActive ? Colors.green.shade900 : Colors.orange.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isActive) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isConnectingStripe ? null : _continueStripeOnboarding,
                                icon: _isConnectingStripe
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.settings),
                                label: Text(_isConnectingStripe
                                    ? 'Loading...'
                                    : 'Complete Setup'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ] else ...[
                  // Not connected state
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isConnectingStripe ? null : _connectStripeAccount,
                      icon: _isConnectingStripe
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.payment),
                      label: Text(_isConnectingStripe
                          ? 'Connecting...'
                          : 'Connect Stripe Account'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Payment Reminder Settings Section
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.notifications_active,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Payment Reminders',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Automatically send payment reminders to clients for unpaid invoices.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                
                // Enable Auto Reminders Switch
                SwitchListTile(
                  value: _enableAutoReminders,
                  onChanged: (value) {
                    setState(() {
                      _enableAutoReminders = value;
                    });
                    _saveSettings(); // Auto-save
                  },
                  title: const Text('Enable Auto Reminders'),
                  subtitle: const Text(
                    'Automatically send reminders based on your settings below',
                  ),
                  activeColor: Theme.of(context).colorScheme.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                
                if (_enableAutoReminders) ...[
                  // Days Before Due Date
                  TextFormField(
                    initialValue: _reminderDaysBeforeDue.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Days Before Due Date',
                      hintText: 'Send reminder X days before due date',
                      border: OutlineInputBorder(),
                      helperText: 'Default: 3 days',
                    ),
                    onChanged: (value) {
                      final days = int.tryParse(value);
                      if (days != null && days >= 0 && days <= 30) {
                        setState(() {
                          _reminderDaysBeforeDue = days;
                        });
                        _saveSettings(); // Auto-save
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Days After Due Date
                  TextFormField(
                    initialValue: _reminderDaysAfterDue.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Days Between Overdue Reminders',
                      hintText: 'Send reminder every X days after due date',
                      border: OutlineInputBorder(),
                      helperText: 'Default: 7 days',
                    ),
                    onChanged: (value) {
                      final days = int.tryParse(value);
                      if (days != null && days >= 1 && days <= 30) {
                        setState(() {
                          _reminderDaysAfterDue = days;
                        });
                        _saveSettings(); // Auto-save
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reminders run daily at 9:00 AM. Clients must have an email address to receive reminders.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
