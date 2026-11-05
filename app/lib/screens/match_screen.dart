import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../match_engine.dart';
import '../models.dart';
import '../scoresheet/scoresheet_publisher.dart';
import 'notes_screen.dart';
import 'sign_off_screen.dart';

enum _MenuAction {
  notes,
  signOff,
  formatLocal,
  formatNational,
  endSet,
  debugPublish,
  reset,
}

extension _TeamStyle on Team {
  Color get accent => this == Team.home ? Colors.blueAccent : Colors.redAccent;
  Color get background =>
      this == Team.home ? const Color(0xFF1E2229) : const Color(0xFF291E1E);
}

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  static const _sheetShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  );
  static const _sheetColor = Color(0xFF222222);

  @override
  void initState() {
    super.initState();
    // Force landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Keep the screen awake during the match
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    // Restore orientation preferences
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Allow the screen to sleep again when leaving the match
    WakelockPlus.disable();
    super.dispose();
  }

  PopupMenuItem<_MenuAction> _menuItem(
    _MenuAction action,
    IconData icon,
    String label, {
    bool enabled = true,
    bool danger = false,
  }) {
    final color = !enabled
        ? Colors.white24
        : (danger ? Colors.redAccent : null);
    return PopupMenuItem<_MenuAction>(
      value: action,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Flexible(child: Text(label, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  void _onMenu(_MenuAction action, MatchEngine engine) {
    switch (action) {
      case _MenuAction.notes:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotesScreen()));
        break;
      case _MenuAction.signOff:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignOffScreen()));
        break;
      case _MenuAction.formatLocal:
        engine.setMatchMode(MatchMode.localLeague3Set);
        break;
      case _MenuAction.formatNational:
        engine.setMatchMode(MatchMode.nationalLeague5Set);
        break;
      case _MenuAction.endSet:
        _showNewSetConfirmationModal(context);
        break;
      case _MenuAction.debugPublish:
        ScoresheetPublisher.publish(context, engine);
        break;
      case _MenuAction.reset:
        _showResetConfirmationModal(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MatchEngine>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          'SpikeScore — Set ${engine.currentSet} (${engine.matchMode == MatchMode.localLeague3Set ? "3-Set" : "5-Set"})',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
          // One button for everything that used to crowd the top bar. A dot
          // appears on it when a set is finished and "End set" is available.
          PopupMenuButton<_MenuAction>(
            tooltip: 'Menu',
            icon: Badge(
              isLabelVisible: engine.isSetComplete && !engine.isMatchComplete,
              smallSize: 10,
              child: const Icon(Icons.menu, color: Colors.white70),
            ),
            onSelected: (action) => _onMenu(action, engine),
            itemBuilder: (context) => [
              _menuItem(_MenuAction.notes, Icons.edit_note, 'Notes'),
              _menuItem(_MenuAction.signOff, Icons.draw, 'Sign-off (captains, officials)'),
              const PopupMenuDivider(),
              _menuItem(
                _MenuAction.formatLocal,
                engine.matchMode == MatchMode.localLeague3Set
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                'Local league (3 sets, set 3 to 15)',
                enabled: !engine.matchStarted,
              ),
              _menuItem(
                _MenuAction.formatNational,
                engine.matchMode == MatchMode.nationalLeague5Set
                    ? Icons.check_box
                    : Icons.check_box_outline_blank,
                'National league (5 sets, set 5 to 15)',
                enabled: !engine.matchStarted,
              ),
              const PopupMenuDivider(),
              _menuItem(
                _MenuAction.endSet,
                Icons.flag,
                'End set',
                enabled: engine.isSetComplete && !engine.isMatchComplete,
              ),
              if (kDebugMode)
                _menuItem(
                  _MenuAction.debugPublish,
                  Icons.picture_as_pdf,
                  'Debug: publish scoresheet now',
                ),
              const PopupMenuDivider(),
              _menuItem(_MenuAction.reset, Icons.refresh, 'Reset match', danger: true),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Shown only if assets/demo/demo_data.json exists but has a mistake.
          if (engine.demoDataError != null)
            Container(
              width: double.infinity,
              color: Colors.orange[800],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'demo_data.json problem: ${engine.demoDataError} (using the built-in teams)',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),

          // Scoreboard section
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(child: _buildTeamPanel(context, engine, engine.leftTeam)),
                      Container(width: 2, color: Colors.black),
                      Expanded(child: _buildTeamPanel(context, engine, engine.rightTeam)),
                    ],
                  ),
                ),
                if (engine.needsSides || engine.needsFirstServe) _buildSetupOverlay(engine),
              ],
            ),
          ),

          // Bottom action bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF1A1A1A),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: engine.canUndo
                      ? () {
                          HapticFeedback.lightImpact();
                          engine.undo();
                        }
                      : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTimeoutModal(context),
                  icon: const Icon(Icons.timer),
                  label: const Text('Timeout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showSubTeamModal(context),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Sub'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TEAM PANEL (tap to score) ---
  Widget _buildTeamPanel(BuildContext context, MatchEngine engine, Team team) {
    final sheet = engine.sheetOf(team);
    final wonSet = engine.isSetComplete && engine.winningTeam == team;
    final isServing = engine.servingTeam == team;
    final server = engine.serverIfWins(team);

    return GestureDetector(
      onTap: engine.isSetComplete
          ? null
          : () {
              HapticFeedback.mediumImpact();
              // The score updates immediately; saving happens in the background.
              engine.scorePoint(team);
              if (engine.isSetComplete) {
                _showSetCompletionModal(context);
              }
            },
      child: Container(
        color: wonSet ? Colors.green[800] : team.background,
        child: Center(
          // Scales the content down on small screens instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isServing) ...[
                      Icon(Icons.sports_volleyball, size: 20, color: team.accent),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      sheet.teamName.toUpperCase(),
                      style: TextStyle(
                        color: team.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Sets Won: ${engine.setsWonOf(team)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Text(
                  '${engine.scoreOf(team)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer, size: 16, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(
                      'Timeouts: ${engine.timeOutsOf(team)}/2',
                      style: const TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Subs: ${engine.subCountOf(team)}/6',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 10),
                if (server != null)
                  Text(
                    isServing
                        ? 'SERVING  #${server.number}'
                        : 'Next server  #${server.number}',
                    style: TextStyle(
                      color: isServing ? team.accent : Colors.white54,
                      fontSize: 15,
                      fontWeight: isServing ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- COIN TOSS: SIDES, THEN FIRST SERVE (covers the scoreboard) ---
  // Only the first set and the deciding set ask. Every other set swaps sides
  // and alternates the first serve by itself.
  Widget _buildSetupOverlay(MatchEngine engine) {
    final choosingSides = engine.needsSides;
    final title = choosingSides
        ? 'Set ${engine.currentSet}: which team is on the left?'
        : 'Set ${engine.currentSet}: who serves first?';

    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final team in Team.values) ...[
                    if (team != Team.home) const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: team.accent,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        if (choosingSides) {
                          engine.chooseSides(team);
                        } else {
                          engine.chooseFirstServe(team);
                        }
                      },
                      child: Text(
                        choosingSides
                            ? '${engine.sheetOf(team).teamName} on the left'
                            : '${engine.sheetOf(team).teamName} serves',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SET / MATCH COMPLETE MODAL ---
  void _showSetCompletionModal(BuildContext context) {
    final engine = context.read<MatchEngine>();
    final winner = engine.winningTeam;
    if (winner == null) return;

    // Capture the numbers now so the sheet doesn't change underneath us.
    final matchDone = engine.isMatchComplete;
    final setNumber = engine.currentSet;
    final homeScore = engine.homeScore;
    final awayScore = engine.awayScore;
    final homeSets = engine.homeSetsWon + (winner == Team.home ? 1 : 0);
    final awaySets = engine.awaySetsWon + (winner == Team.away ? 1 : 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                matchDone ? 'Match Complete! 🏆' : 'Set $setNumber Complete!',
                style: TextStyle(
                  color: matchDone ? Colors.amberAccent : Colors.greenAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Winner of Set $setNumber: ${winner.label} Team ($homeScore - $awayScore)',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                matchDone
                    ? '${winner.label} Team wins the match $homeSets - $awaySets!'
                    : 'Tap below to proceed to Set ${setNumber + 1}.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => ScoresheetPublisher.publish(modalContext, engine),
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: Text(matchDone ? 'Publish final scoresheet (PDF)' : 'Publish scoresheet so far (PDF)'),
                style: TextButton.styleFrom(foregroundColor: Colors.lightBlueAccent),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                      onPressed: () => Navigator.pop(modalContext),
                      child: Text(
                        matchDone ? 'Close' : 'Review Score',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  if (!matchDone) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(modalContext);
                          engine.startNewSet();
                        },
                        child: Text(
                          'Start Set ${setNumber + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  // --- NEW SET CONFIRMATION MODAL ---
  void _showNewSetConfirmationModal(BuildContext context) {
    final engine = context.read<MatchEngine>();
    final setNumber = engine.currentSet;
    final homeScore = engine.homeScore;
    final awayScore = engine.awayScore;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'End Set $setNumber?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Score: Home $homeScore — $awayScore Away',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'This will log the set score and reset timeouts, subs, and rotation for Set ${setNumber + 1}. You will choose who serves first.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                      onPressed: () => Navigator.pop(modalContext),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(modalContext);
                        engine.startNewSet();
                      },
                      child: Text(
                        'Start Set ${setNumber + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  // --- RESET MATCH CONFIRMATION MODAL ---
  void _showResetConfirmationModal(BuildContext context) {
    final engine = context.read<MatchEngine>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Entire Match?',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This will wipe all scores, sets, timeouts, substitutions, and undo history back to zero.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                      onPressed: () => Navigator.pop(modalContext),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(modalContext);
                        engine.resetMatch();
                      },
                      child: const Text(
                        'Reset Match',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  // --- TIMEOUT MODAL ---
  void _showTimeoutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Request Time-Out',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select team taking the time-out:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final team in Team.values) ...[
                    if (team != Team.home) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: team.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: engine.timeOutsOf(team) >= 2
                            ? null
                            : () {
                                HapticFeedback.mediumImpact();
                                Navigator.pop(modalContext);
                                engine.takeTimeout(team);
                              },
                        child: Text(
                          '${team.label} (${engine.timeOutsOf(team)}/2)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
          ),
        );
      },
    );
  }

  // --- SUB STEP 1: PICK TEAM ---
  void _showSubTeamModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();

        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Substitution',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select team making a substitution:',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final team in Team.values) ...[
                    if (team != Team.home) const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: team.accent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: !engine.canTakeSub(team)
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(modalContext);
                                _showPlayerOffModal(context, team);
                              },
                        child: Text(
                          '${team.label} (${engine.subCountOf(team)}/6)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
          ),
        );
      },
    );
  }

  // --- SUB STEP 2: PICK PLAYER OFF (ON COURT, shown in position order I-VI) ---
  void _showPlayerOffModal(BuildContext context, Team team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();
        final onCourt = engine.getOnCourtPlayers(team);

        return SafeArea(
          top: false,
          child: Container(
          padding: const EdgeInsets.all(24),
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${team.label} Team - Select Player Coming OFF',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: onCourt.length,
                  itemBuilder: (context, index) {
                    final Player p = onCourt[index];
                    final int subCount = engine.getSubCountForPlayer(team, p.number);
                    final bool isExhausted = engine.isPositionExhausted(team, p.number);
                    final Player? lockedPartner = engine.getLockedSubPartner(team, p.number);

                    Color btnColor = Colors.grey[800]!;
                    String statusLabel = p.position;

                    if (isExhausted) {
                      btnColor = Colors.red[900]!;
                      statusLabel = "Sub Maxed (2/2)";
                    } else if (subCount == 1) {
                      btnColor = Colors.amber[900]!;
                      statusLabel = "Re-entry Pending";
                    }

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: btnColor,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      onPressed: isExhausted
                          ? null // Disabled when 2/2 subs used for this position
                          : () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(modalContext);
                              if (subCount == 1 && lockedPartner != null) {
                                _showLockedSubConfirmationModal(context, team, p, lockedPartner);
                              } else {
                                _showPlayerOnModal(context, team, p.number);
                              }
                            },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#${p.number} ${p.name}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: subCount == 1
                                  ? Colors.amberAccent
                                  : (isExhausted ? Colors.redAccent[100] : Colors.white54),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  // --- SUB STEP 3A: AUTO RE-ENTRY CONFIRMATION MODAL ---
  void _showLockedSubConfirmationModal(
    BuildContext context,
    Team team,
    Player playerOff,
    Player lockedPlayerOn,
  ) {
    // Capture the engine from the main screen's context before opening the sheet.
    final engine = context.read<MatchEngine>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.swap_horiz, color: Colors.amberAccent, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Confirm Re-entry',
                    style: TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Subbing off #${playerOff.number} (${playerOff.name}). Original starter #${lockedPlayerOn.number} (${lockedPlayerOn.name}) will automatically re-enter.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                      onPressed: () => Navigator.pop(modalContext),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(modalContext);
                        engine.executeSubstitution(team, playerOff.number, lockedPlayerOn.number);
                      },
                      child: Text(
                        'Confirm #${lockedPlayerOn.number} ON',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  // --- SUB STEP 3B: PICK PLAYER ON FROM BENCH ---
  void _showPlayerOnModal(BuildContext context, Team team, int playerOffNum) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();
        final bench = engine.getEligibleBenchPlayers(team, playerOffNum);

        return SafeArea(
          top: false,
          child: Container(
          padding: const EdgeInsets.all(24),
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${team.label} Team - Select Player Coming ON for #$playerOffNum',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: bench.isEmpty
                    ? const Center(
                        child: Text('No eligible bench players', style: TextStyle(color: Colors.white54)),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: bench.length,
                        itemBuilder: (context, index) {
                          final Player p = bench[index];
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(modalContext);
                              engine.executeSubstitution(team, playerOffNum, p.number);
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '#${p.number} ${p.name}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  p.position,
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }
}
