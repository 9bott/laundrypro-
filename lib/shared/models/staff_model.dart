import '../../core/constants/supabase_constants.dart';
import 'model_parsing.dart';

class StaffModel {
  const StaffModel({
    required this.id,
    this.authUserId,
    required this.phone,
    required this.name,
    this.pinHash,
    required this.role,
    required this.branch,
    required this.isActive,
    this.lastLogin,
    required this.createdAt,
  });

  final String id;
  final String? authUserId;
  final String phone;
  final String name;
  final String? pinHash;
  final String role;
  final String branch;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;

  factory StaffModel.fromJson(Map<String, dynamic> json) {
    return StaffModel(
      id: json[kStaffId]! as String,
      authUserId: modelParseString(json[kStaffAuthUserId]),
      phone: json[kStaffPhone]! as String,
      name: json[kStaffName]! as String,
      pinHash: modelParseString(json[kStaffPinHash]),
      role: json[kStaffRole] as String? ?? 'staff',
      branch: json[kStaffBranch] as String? ?? 'main',
      isActive: modelParseBool(json[kStaffIsActive], true),
      lastLogin: modelParseDateTime(json[kStaffLastLogin]),
      createdAt: modelParseDateTime(json[kStaffCreatedAt])!,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      kStaffId: id,
      kStaffAuthUserId: authUserId,
      kStaffPhone: phone,
      kStaffName: name,
      kStaffPinHash: pinHash,
      kStaffRole: role,
      kStaffBranch: branch,
      kStaffIsActive: isActive,
      kStaffLastLogin: lastLogin?.toUtc().toIso8601String(),
      kStaffCreatedAt: createdAt.toUtc().toIso8601String(),
    };
  }

  StaffModel copyWith({
    String? id,
    String? authUserId,
    String? phone,
    String? name,
    String? pinHash,
    String? role,
    String? branch,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? createdAt,
    bool clearAuthUserId = false,
    bool clearPinHash = false,
    bool clearLastLogin = false,
  }) {
    return StaffModel(
      id: id ?? this.id,
      authUserId: clearAuthUserId ? null : (authUserId ?? this.authUserId),
      phone: phone ?? this.phone,
      name: name ?? this.name,
      pinHash: clearPinHash ? null : (pinHash ?? this.pinHash),
      role: role ?? this.role,
      branch: branch ?? this.branch,
      isActive: isActive ?? this.isActive,
      lastLogin: clearLastLogin ? null : (lastLogin ?? this.lastLogin),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
