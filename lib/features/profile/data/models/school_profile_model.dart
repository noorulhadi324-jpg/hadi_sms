class SchoolProfileModel {
  final String id;
  final String schoolName;
  final String address;
  final String contactNumber;
  final String email;
  final String? website;
  final String? logoUrl;
  final String affiliationDetails;

  SchoolProfileModel({
    required this.id,
    required this.schoolName,
    required this.address,
    required this.contactNumber,
    required this.email,
    this.website,
    this.logoUrl,
    required this.affiliationDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolName': schoolName,
      'address': address,
      'contactNumber': contactNumber,
      'email': email,
      'website': website,
      'logoUrl': logoUrl,
      'affiliationDetails': affiliationDetails,
    };
  }

  factory SchoolProfileModel.fromMap(Map<String, dynamic> map) {
    return SchoolProfileModel(
      id: map['id'] ?? '',
      schoolName: map['schoolName'] ?? '',
      address: map['address'] ?? '',
      contactNumber: map['contactNumber'] ?? '',
      email: map['email'] ?? '',
      website: map['website'],
      logoUrl: map['logoUrl'],
      affiliationDetails: map['affiliationDetails'] ?? '',
    );
  }
}
