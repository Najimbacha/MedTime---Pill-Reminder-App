import 'package:flutter/material.dart';
import '../services/streak_service.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unlockedIds = StreakService.instance.unlockedAchievements;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
        title: Text(
          'Achievements',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: allAchievements.length,
        itemBuilder: (context, index) {
          final achievement = allAchievements[index];
          final isUnlocked = unlockedIds.contains(achievement.id);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUnlocked
                    ? (isDark ? Colors.amber.withOpacity(0.3) : Colors.amber)
                    : (isDark ? Colors.white10 : Colors.black12),
                width: isUnlocked ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isUnlocked
                        ? Colors.amber.withOpacity(0.15)
                        : (isDark ? Colors.white10 : Colors.black12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      isUnlocked ? achievement.emoji : '🔒',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        achievement.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark 
                              ? (isUnlocked ? Colors.white : Colors.white54)
                              : (isUnlocked ? Colors.black : Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnlocked)
                  Icon(
                    Icons.check_circle_rounded,
                    color: isDark ? Colors.amber : Colors.amber.shade700,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
