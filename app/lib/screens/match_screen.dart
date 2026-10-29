import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../match_engine.dart';
import '../models.dart';

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
          // MODE SWITCHER (locked once the match has started)
          PopupMenuButton<MatchMode>(
            enabled: !engine.matchStarted,
            icon: Icon(
              Icons.settings,
              color: engine.matchStarted ? Colors.white24 : Colors.white70,
            ),
            tooltip: 'Match Format',
            onSelected: (MatchMode mode) {
              engine.setMatchMode(mode);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: MatchMode.localLeague3Set,
                child: Text('Local League (3 Sets, Set 3 to 15)'),
              ),
              PopupMenuItem(
                value: MatchMode.nationalLeague5Set,
                child: Text('National League (5 Sets, Set 5 to 15)'),
              ),
            ],
          ),
          const SizedBox(width: 4),

          // SERVICE ROUNDS (scoresheet-style view)
          IconButton(
            onPressed: () => _showServiceRoundsModal(context),
            icon: const Icon(Icons.format_list_numbered, color: Colors.white70),
            tooltip: 'Service rounds',
          ),
          const SizedBox(width: 4),

          // RESET MATCH
          IconButton(
            onPressed: () => _showResetConfirmationModal(context),
            icon: const Icon(Icons.refresh, color: Colors.redAccent),
            tooltip: 'Reset Match',
          ),
          const SizedBox(width: 4),

          // END SET (only once the set is actually complete)
          TextButton.icon(
            onPressed: (engine.isSetComplete && !engine.isMatchComplete)
                ? () => _showNewSetConfirmationModal(context)
                : null,
            icon: const Icon(Icons.flag),
            label: const Text('End Set', style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              foregroundColor: Colors.amberAccent,
              disabledForegroundColor: Colors.white24,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Scoreboard section
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(child: _buildTeamPanel(context, engine, Team.home)),
                      Container(width: 2, color: Colors.black),
                      Expanded(child: _buildTeamPanel(context, engine, Team.away)),
                    ],
                  ),
                ),
                if (engine.needsFirstServe) _buildFirstServeOverlay(engine),
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

  // --- FIRST SERVE CHOOSER (covers the scoreboard until a team is picked) ---
  Widget _buildFirstServeOverlay(MatchEngine engine) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set ${engine.currentSet}: who serves first?',
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
                        engine.chooseFirstServe(team);
                      },
                      child: Text(
                        '${engine.sheetOf(team).teamName} serves',
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
      isDismissible: false,
      enableDrag: false,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 230,
          child: Column(
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
              const Spacer(),
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
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 220,
          child: Column(
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
              const Spacer(),
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
        );
      },
    );
  }

  // --- RESET MATCH CONFIRMATION MODAL ---
  void _showResetConfirmationModal(BuildContext context) {
    final engine = context.read<MatchEngine>();
    showModalBottomSheet(
      context: context,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 200,
          child: Column(
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
              const Spacer(),
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
        );
      },
    );
  }

  // --- SERVICE ROUNDS (paper-sheet style view of the current set) ---
  void _showServiceRoundsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();

        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(modalContext).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service rounds — Set ${engine.currentSet}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                "Each number is the team's score when its service round ended. Highlighted = in progress.",
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (final team in Team.values) _buildServiceTeamBlock(engine, team),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceTeamBlock(MatchEngine engine, Team team) {
    final sheet = engine.sheetOf(team);
    final rounds = engine.serviceRoundsFor(team);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sheet.teamName.toUpperCase(),
            style: TextStyle(color: team.accent, fontWeight: FontWeight.bold, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var slot = 0; slot < 6; slot++)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        '${ServiceRound.romanNumerals[slot]}  #${sheet.startingLineup[slot]}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 10, color: Colors.white24),
                      for (final r in rounds.where((r) => r.position == slot + 1))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${r.endOwn}',
                            style: TextStyle(
                              color: r.isOpen ? team.accent : Colors.white,
                              fontSize: 16,
                              fontWeight: r.isOpen ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // --- TIMEOUT MODAL ---
  void _showTimeoutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();

        return Container(
          padding: const EdgeInsets.all(24),
          height: 200,
          child: Column(
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
              const Spacer(),
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
              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  // --- SUB STEP 1: PICK TEAM ---
  void _showSubTeamModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();

        return Container(
          padding: const EdgeInsets.all(24),
          height: 200,
          child: Column(
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
              const Spacer(),
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
              const Spacer(),
            ],
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

        return Container(
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
      backgroundColor: _sheetColor,
      shape: _sheetShape,
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 220,
          child: Column(
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
              const Spacer(),
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

        return Container(
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
        );
      },
    );
  }
}
