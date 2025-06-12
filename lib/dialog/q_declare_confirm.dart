import 'package:flutter/material.dart';
import 'package:q_officer_barantin/main.dart';

Future<void> showAnimatedConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  required IconData icon,
  required Color iconColor,
  required VoidCallback onConfirm,
}) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Konfirmasi Dialog",
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (context, animation1, animation2) => const SizedBox(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation =
      CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
      return ScaleTransition(
        scale: Tween<double>(begin: 0.6, end: 1.0).animate(curvedAnimation),
        child: FadeTransition(
          opacity:
          Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
          child: _ConfirmationDialogContent(
            title: title,
            message: message,
            icon: icon,
            iconColor: iconColor,
            onConfirm: onConfirm,
          ),
        ),
      );
    },
  );
}

class _ConfirmationDialogContent extends StatefulWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onConfirm;

  const _ConfirmationDialogContent({
    required this.title,
    required this.message,
    required this.icon,
    required this.iconColor,
    required this.onConfirm,
  });

  @override
  _ConfirmationDialogContentState createState() =>
      _ConfirmationDialogContentState();
}

class _ConfirmationDialogContentState extends State<_ConfirmationDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _iconController;
  late Animation<double> _iconScaleAnimation;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _iconScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 1.25)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 65),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.25, end: 1.0)
              .chain(CurveTween(curve: Curves.easeInOutSine)),
          weight: 35),
    ]).animate(
        CurvedAnimation(parent: _iconController, curve: Curves.linear));

    Future.delayed(
        const Duration(milliseconds: 150), () => _iconController.forward());
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
                animation: _iconController,
                builder: (context, child) => Transform.scale(
                    scale: _iconScaleAnimation.value, child: child),
                child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.iconColor.withOpacity(0.1)),
                    child:
                    Icon(widget.icon, size: 50, color: widget.iconColor))),
            const SizedBox(height: 20),
            Text(widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: MyApp.karantinaBrown)),
            const SizedBox(height: 12),
            Text(widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.grey[800], fontSize: 15, height: 1.3)),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: MyApp.karantinaBrown,
                        side: const BorderSide(
                            color: MyApp.karantinaBrown, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Batal',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: MyApp.karantinaBrown,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    child: const Text('Ya, Lanjutkan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}