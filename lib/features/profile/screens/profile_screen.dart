import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../habits/logic/habit_provider.dart';
import 'dart:math';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showEditNameDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController nameController = TextEditingController(
      text: ref.read(userProvider).name,
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          title: Text(
            'Edit Name',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              hintText: 'Enter your name',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  ref.read(userProvider.notifier).setName(newName);
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showResetAppDialog(BuildContext context, WidgetRef ref) {
    // Generate a random 4-digit verification code to simulate 2FA
    final randomCode = (Random().nextInt(9000) + 1000).toString();
    final TextEditingController codeController = TextEditingController();
    bool codeError = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              title: const Text(
                'Security Verification',
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete all your habits, records, and settings.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'To verify, please enter the following code:',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      randomCode,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter 4-digit code',
                      errorText: codeError ? 'Incorrect verification code' : null,
                      counterText: '',
                    ),
                    onChanged: (val) {
                      if (codeError) setState(() => codeError = false);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                  onPressed: () async {
                    if (codeController.text == randomCode) {
                      // Perform Wipe
                      await ref.read(habitProvider.notifier).clearAll();
                      await ref.read(userProvider.notifier).reset();
                      
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Close dialog
                        Navigator.of(context).pop(); // Go back from profile to reload App view
                      }
                    } else {
                      setState(() => codeError = true);
                    }
                  },
                  child: const Text('Reset Everything'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userState = ref.watch(userProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      extendBodyBehindAppBar: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.1), 
                    width: 8,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  radius: 60,
                  child: Icon(
                    Icons.person, 
                    color: colorScheme.primary, 
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  userState.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28, 
                    fontWeight: FontWeight.w900, 
                    color: colorScheme.onSurface, 
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'HabitTrace Member', 
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 40),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.onSurface.withValues(alpha: 0.04), 
                        blurRadius: 20, 
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildProfileItem(
                        Icons.edit_outlined, 
                        'Change Name', 
                        colorScheme.onSurface,
                        onTap: () => _showEditNameDialog(context, ref),
                      ),
                      Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.5), indent: 56),
                      _buildProfileItem(
                        Icons.dark_mode_outlined, 
                        'Switch Theme', 
                        colorScheme.onSurface,
                        onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                      ),
                      Divider(height: 1, color: colorScheme.outlineVariant.withOpacity(0.5), indent: 56),
                      _buildProfileItem(
                        Icons.delete_forever_outlined, 
                        'Reset App Data', 
                        Colors.redAccent,
                        onTap: () => _showResetAppDialog(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileItem(IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap ?? () {},
    );
  }
}
