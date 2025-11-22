class UserSettings {
  final String id;
  final String userId;
  final String? companyName;
  final String? companyEmail;
  final String? companyPhone;
  final String? companyAddress;
  final String? companyCity;
  final String? companyProvince;
  final String? companyPostal;
  final String? companyCountry;
  final String? companyTaxNumber;
  final String? companyWebsite;
  final String? companyLogoUrl;
  final String? googleDriveFolderName;
  final String? googleDriveFolderId;
  final bool? enableAutoReminders;
  final int? reminderDaysBeforeDue;
  final int? reminderDaysAfterDue;
  final double? defaultTaxRate;
  final String? defaultPaymentTerms;
  final String? currency;
  final String? defaultInvoiceNotes;
  final String? invoiceNumberPrefix;
  // PDF Customization
  final String? pdfPrimaryColor;
  final String? pdfSecondaryColor;
  final String? pdfAccentColor;
  final String? pdfBackgroundColor;
  final bool? pdfWatermarkEnabled;
  final String? pdfWatermarkText;
  final int? pdfWatermarkOpacity;
  final String? pdfTableStyle;
  final String? pdfLayoutStyle;
  final String? pdfFontFamily;
  final String? pdfReferenceImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettings({
    required this.id,
    required this.userId,
    this.companyName,
    this.companyEmail,
    this.companyPhone,
    this.companyAddress,
    this.companyCity,
    this.companyProvince,
    this.companyPostal,
    this.companyCountry,
    this.companyTaxNumber,
    this.companyWebsite,
    this.companyLogoUrl,
    this.googleDriveFolderName,
    this.googleDriveFolderId,
    this.enableAutoReminders,
    this.reminderDaysBeforeDue,
    this.reminderDaysAfterDue,
    this.defaultTaxRate,
    this.defaultPaymentTerms,
    this.currency,
    this.defaultInvoiceNotes,
    this.invoiceNumberPrefix,
    this.pdfPrimaryColor,
    this.pdfSecondaryColor,
    this.pdfAccentColor,
    this.pdfBackgroundColor,
    this.pdfWatermarkEnabled,
    this.pdfWatermarkText,
    this.pdfWatermarkOpacity,
    this.pdfTableStyle,
    this.pdfLayoutStyle,
    this.pdfFontFamily,
    this.pdfReferenceImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['id'] as String,
      userId: json['userId'] as String,
      companyName: json['companyName'] as String?,
      companyEmail: json['companyEmail'] as String?,
      companyPhone: json['companyPhone'] as String?,
      companyAddress: json['companyAddress'] as String?,
      companyCity: json['companyCity'] as String?,
      companyProvince: json['companyProvince'] as String?,
      companyPostal: json['companyPostal'] as String?,
      companyCountry: json['companyCountry'] as String?,
      companyTaxNumber: json['companyTaxNumber'] as String?,
      companyWebsite: json['companyWebsite'] as String?,
      companyLogoUrl: json['companyLogoUrl'] as String?,
      googleDriveFolderName: json['googleDriveFolderName'] as String?,
      googleDriveFolderId: json['googleDriveFolderId'] as String?,
      enableAutoReminders: json['enableAutoReminders'] as bool?,
      reminderDaysBeforeDue: json['reminderDaysBeforeDue'] != null 
          ? int.parse(json['reminderDaysBeforeDue'].toString()) 
          : null,
      reminderDaysAfterDue: json['reminderDaysAfterDue'] != null 
          ? int.parse(json['reminderDaysAfterDue'].toString()) 
          : null,
      defaultTaxRate: json['defaultTaxRate'] != null 
          ? (json['defaultTaxRate'] as num).toDouble() 
          : null,
      defaultPaymentTerms: json['defaultPaymentTerms'] as String?,
      currency: json['currency'] as String? ?? 'USD',
      defaultInvoiceNotes: json['defaultInvoiceNotes'] as String?,
      invoiceNumberPrefix: json['invoiceNumberPrefix'] as String? ?? 'INV',
      pdfPrimaryColor: json['pdfPrimaryColor'] as String?,
      pdfSecondaryColor: json['pdfSecondaryColor'] as String?,
      pdfAccentColor: json['pdfAccentColor'] as String?,
      pdfBackgroundColor: json['pdfBackgroundColor'] as String?,
      pdfWatermarkEnabled: json['pdfWatermarkEnabled'] as bool?,
      pdfWatermarkText: json['pdfWatermarkText'] as String?,
      pdfWatermarkOpacity: json['pdfWatermarkOpacity'] != null
          ? int.parse(json['pdfWatermarkOpacity'].toString())
          : null,
      pdfTableStyle: json['pdfTableStyle'] as String?,
      pdfLayoutStyle: json['pdfLayoutStyle'] as String?,
      pdfFontFamily: json['pdfFontFamily'] as String?,
      pdfReferenceImageUrl: json['pdfReferenceImageUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'companyName': companyName,
      'companyEmail': companyEmail,
      'companyPhone': companyPhone,
      'companyAddress': companyAddress,
      'companyCity': companyCity,
      'companyProvince': companyProvince,
      'companyPostal': companyPostal,
      'companyCountry': companyCountry,
      'companyTaxNumber': companyTaxNumber,
      'companyWebsite': companyWebsite,
      'companyLogoUrl': companyLogoUrl,
      'googleDriveFolderName': googleDriveFolderName,
      'googleDriveFolderId': googleDriveFolderId,
      'enableAutoReminders': enableAutoReminders,
      'reminderDaysBeforeDue': reminderDaysBeforeDue,
      'reminderDaysAfterDue': reminderDaysAfterDue,
      'defaultTaxRate': defaultTaxRate,
      'defaultPaymentTerms': defaultPaymentTerms,
      'currency': currency,
      'defaultInvoiceNotes': defaultInvoiceNotes,
      'invoiceNumberPrefix': invoiceNumberPrefix,
      'pdfPrimaryColor': pdfPrimaryColor,
      'pdfSecondaryColor': pdfSecondaryColor,
      'pdfAccentColor': pdfAccentColor,
      'pdfBackgroundColor': pdfBackgroundColor,
      'pdfWatermarkEnabled': pdfWatermarkEnabled,
      'pdfWatermarkText': pdfWatermarkText,
      'pdfWatermarkOpacity': pdfWatermarkOpacity,
      'pdfTableStyle': pdfTableStyle,
      'pdfLayoutStyle': pdfLayoutStyle,
      'pdfFontFamily': pdfFontFamily,
      'pdfReferenceImageUrl': pdfReferenceImageUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  UserSettings copyWith({
    String? id,
    String? userId,
    String? companyName,
    String? companyEmail,
    String? companyPhone,
    String? companyAddress,
    String? companyCity,
    String? companyProvince,
    String? companyPostal,
    String? companyCountry,
    String? companyTaxNumber,
    String? companyWebsite,
    String? companyLogoUrl,
    String? googleDriveFolderName,
    String? googleDriveFolderId,
    bool? enableAutoReminders,
    int? reminderDaysBeforeDue,
    int? reminderDaysAfterDue,
    double? defaultTaxRate,
    String? defaultPaymentTerms,
    String? currency,
    String? defaultInvoiceNotes,
    String? invoiceNumberPrefix,
    String? pdfPrimaryColor,
    String? pdfSecondaryColor,
    String? pdfAccentColor,
    String? pdfBackgroundColor,
    bool? pdfWatermarkEnabled,
    String? pdfWatermarkText,
    int? pdfWatermarkOpacity,
    String? pdfTableStyle,
    String? pdfLayoutStyle,
    String? pdfFontFamily,
    String? pdfReferenceImageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyName: companyName ?? this.companyName,
      companyEmail: companyEmail ?? this.companyEmail,
      companyPhone: companyPhone ?? this.companyPhone,
      companyAddress: companyAddress ?? this.companyAddress,
      companyCity: companyCity ?? this.companyCity,
      companyProvince: companyProvince ?? this.companyProvince,
      companyPostal: companyPostal ?? this.companyPostal,
      companyCountry: companyCountry ?? this.companyCountry,
      companyTaxNumber: companyTaxNumber ?? this.companyTaxNumber,
      companyWebsite: companyWebsite ?? this.companyWebsite,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      googleDriveFolderName: googleDriveFolderName ?? this.googleDriveFolderName,
      googleDriveFolderId: googleDriveFolderId ?? this.googleDriveFolderId,
      enableAutoReminders: enableAutoReminders ?? this.enableAutoReminders,
      reminderDaysBeforeDue: reminderDaysBeforeDue ?? this.reminderDaysBeforeDue,
      reminderDaysAfterDue: reminderDaysAfterDue ?? this.reminderDaysAfterDue,
      defaultTaxRate: defaultTaxRate ?? this.defaultTaxRate,
      defaultPaymentTerms: defaultPaymentTerms ?? this.defaultPaymentTerms,
      currency: currency ?? this.currency,
      defaultInvoiceNotes: defaultInvoiceNotes ?? this.defaultInvoiceNotes,
      invoiceNumberPrefix: invoiceNumberPrefix ?? this.invoiceNumberPrefix,
      pdfPrimaryColor: pdfPrimaryColor ?? this.pdfPrimaryColor,
      pdfSecondaryColor: pdfSecondaryColor ?? this.pdfSecondaryColor,
      pdfAccentColor: pdfAccentColor ?? this.pdfAccentColor,
      pdfBackgroundColor: pdfBackgroundColor ?? this.pdfBackgroundColor,
      pdfWatermarkEnabled: pdfWatermarkEnabled ?? this.pdfWatermarkEnabled,
      pdfWatermarkText: pdfWatermarkText ?? this.pdfWatermarkText,
      pdfWatermarkOpacity: pdfWatermarkOpacity ?? this.pdfWatermarkOpacity,
      pdfTableStyle: pdfTableStyle ?? this.pdfTableStyle,
      pdfLayoutStyle: pdfLayoutStyle ?? this.pdfLayoutStyle,
      pdfFontFamily: pdfFontFamily ?? this.pdfFontFamily,
      pdfReferenceImageUrl: pdfReferenceImageUrl ?? this.pdfReferenceImageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

