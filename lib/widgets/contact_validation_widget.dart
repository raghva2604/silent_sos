import 'package:flutter/material.dart';
import '../services/email_validator.dart';

/// UI widget that shows validation status for email/phone
class ContactValidationTile extends StatelessWidget {
  final String name;
  final String? email;
  final String? phone;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback? onRemove;

  const ContactValidationTile({
    required this.name,
    this.email,
    this.phone,
    required this.isSelected,
    required this.onToggle,
    this.onRemove,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final emailValid = email != null ? EmailValidator.isValidEmail(email!) : true;
    final phoneValid = phone != null ? EmailValidator.isValidPhone(phone!) : true;
    final allValid = emailValid && phoneValid;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: allValid ? Colors.green[300]! : Colors.orange[300]!,
          width: 2,
        ),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: allValid ? Colors.green[200] : Colors.orange[200],
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (email != null)
              Row(
                children: [
                  Icon(
                    emailValid ? Icons.check_circle : Icons.error,
                    size: 14,
                    color: emailValid ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      email!,
                      style: TextStyle(
                        fontSize: 12,
                        color: emailValid
                            ? Colors.black54
                            : Colors.orange[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (phone != null)
              Row(
                children: [
                  Icon(
                    phoneValid ? Icons.check_circle : Icons.error,
                    size: 14,
                    color: phoneValid ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      phone!,
                      style: TextStyle(
                        fontSize: 12,
                        color: phoneValid
                            ? Colors.black54
                            : Colors.orange[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: onRemove,
              ),
            Checkbox(
              value: isSelected,
              activeColor: Colors.teal,
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
        onTap: onToggle,
      ),
    );
  }
}

/// Summary widget for validation results
class ValidationSummary extends StatelessWidget {
  final int totalContacts;
  final int validContacts;
  final int totalEmails;
  final int validEmails;

  const ValidationSummary({
    required this.totalContacts,
    required this.validContacts,
    required this.totalEmails,
    required this.validEmails,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final allValid = validContacts == totalContacts && validEmails == totalEmails;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                allValid ? '✅ All Valid' : '⚠️ Issues Found',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: allValid ? Colors.green : Colors.orange,
                ),
              ),
              Icon(
                allValid ? Icons.check_circle : Icons.warning,
                color: allValid ? Colors.green : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contacts: $validContacts/$totalContacts',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
              Text(
                'Emails: $validEmails/$totalEmails',
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
