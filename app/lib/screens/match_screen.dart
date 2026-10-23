import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart'; // Import wakelock
import '../match_engine.dart';
import '../models.dart';

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  @override
  void initState() {
    super.initState();
    // Force landscape mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // KEEP SCREEN AWAKE
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
    
    // ALLOW SCREEN TO SLEEP AGAIN WHEN LEAVING MATCH
    WakelockPlus.disable();
    super.dispose();
  }

  // ... rest of your MatchScreen code remains identical

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<MatchEngine>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text('SpikeScore — Set ${engine.currentSet} (${engine.matchMode == MatchMode.localLeague3Set ? "3-Set" : "5-Set"})', style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E1E1E),
        elevation: 0,
        actions: [
          // MODE SWITCHER
          PopupMenuButton<MatchMode>(
            icon: const Icon(Icons.settings, color: Colors.white70),
            tooltip: 'Match Format',
            onSelected: (MatchMode mode) {
              engine.setMatchMode(mode);
            },
            itemBuilder: (context) => [
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

          // RESET MATCH
          IconButton(
            onPressed: () => _showResetConfirmationModal(context),
            icon: const Icon(Icons.refresh, color: Colors.redAccent),
            tooltip: 'Reset Match',
          ),
          const SizedBox(width: 4),

          // END / NEW SET BUTTON
          TextButton.icon(
            onPressed: () => _showNewSetConfirmationModal(context),
            icon: const Icon(Icons.flag, color: Colors.amberAccent),
            label: const Text('End Set', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Scoreboard Section
          Expanded(
            child: Row(
              children: [
                // HOME TEAM
                Expanded(
                  child: GestureDetector(
                    onTap: engine.isSetComplete
                        ? null // Disables scoring when set is complete
                        : () {
                            HapticFeedback.mediumImpact();
                            engine.scorePoint("Home");
                            if (engine.isSetComplete) {
                              _showSetCompletionModal(context);
                            }
                          },
                    child: Container(
                      color: (engine.isSetComplete && engine.winningTeam == "Home")
                          ? Colors.green[800] // Green highlight when Home wins set
                          : const Color(0xFF1E2229),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(engine.homeTeamSheet.teamName.toUpperCase(), style: const TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          const SizedBox(height: 10),
                          Text('Sets Won: ${engine.homeSetsWon}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          const SizedBox(height: 10),
                          Text('${engine.homeScore}', style: const TextStyle(color: Colors.white, fontSize: 70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer, size: 16, color: Colors.white54),
                              const SizedBox(width: 6),
                              Text('Timeouts: ${engine.homeTimeOuts}/2', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Subs: ${engine.homeSubCount}/6', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
                
                Container(width: 2, color: Colors.black),

                // AWAY TEAM
                Expanded(
                  child: GestureDetector(
                    onTap: engine.isSetComplete
                        ? null // Disables scoring when set is complete
                        : () {
                            HapticFeedback.mediumImpact();
                            engine.scorePoint("Away");
                            if (engine.isSetComplete) {
                              _showSetCompletionModal(context);
                            }
                          },
                    child: Container(
                      color: (engine.isSetComplete && engine.winningTeam == "Away")
                          ? Colors.green[800] // Green highlight when Away wins set
                          : const Color(0xFF291E1E),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(engine.awayTeamSheet.teamName.toUpperCase(), style: const TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                          const SizedBox(height: 10),
                          Text('Sets Won: ${engine.awaySetsWon}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          const SizedBox(height: 10),
                          Text('${engine.awayScore}', style: const TextStyle(color: Colors.white, fontSize: 70, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.timer, size: 16, color: Colors.white54),
                              const SizedBox(width: 6),
                              Text('Timeouts: ${engine.awayTimeOuts}/2', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Subs: ${engine.awaySubCount}/6', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar
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
                          engine.undo(); // Undoing the winning point unlocks scoring again
                        }
                      : null,
                  icon: const Icon(Icons.undo),
                  label: const Text('Undo'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTimeoutModal(context),
                  icon: const Icon(Icons.timer),
                  label: const Text('Timeout'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showSubTeamModal(context),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Sub'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SET / MATCH COMPLETE MODAL ---
  void _showSetCompletionModal(BuildContext context) {
    final engine = context.read<MatchEngine>();
    bool matchDone = engine.isMatchComplete;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 230,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                matchDone ? 'Match Complete! 🏆' : 'Set ${engine.currentSet} Complete!',
                style: TextStyle(color: matchDone ? Colors.amberAccent : Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Winner of Set ${engine.currentSet}: ${engine.winningTeam} Team (${engine.homeScore} - ${engine.awayScore})',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                matchDone
                    ? '${engine.winningTeam} Team wins the match ${engine.winningTeam == "Home" ? engine.homeSetsWon + 1 : engine.homeSetsWon} - ${engine.winningTeam == "Away" ? engine.awaySetsWon + 1 : engine.awaySetsWon}!'
                    : 'Tap below to proceed to Set ${engine.currentSet + 1}.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                      onPressed: () => Navigator.pop(modalContext),
                      child: Text(matchDone ? 'Close' : 'Review Score', style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                  if (!matchDone) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(modalContext);
                          await engine.startNewSet();
                        },
                        child: Text('Start Set ${engine.currentSet + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('End Set ${engine.currentSet}?', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Score: Home ${engine.homeScore} — ${engine.awayScore} Away', style: const TextStyle(color: Colors.amberAccent, fontSize: 16)),
              const SizedBox(height: 4),
              Text('This will log the set score and reset timeouts, subs, and rotation for Set ${engine.currentSet + 1}.', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(modalContext);
                        await engine.startNewSet();
                      },
                      child: Text('Start Set ${engine.currentSet + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Reset Entire Match?', style: TextStyle(color: Colors.redAccent, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('This will wipe all scores, sets, timeouts, substitutions, and undo history back to zero.', style: TextStyle(color: Colors.white70, fontSize: 13)),
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
                      onPressed: () async {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(modalContext);
                        await engine.resetMatch();
                      },
                      child: const Text('Reset Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  // --- TIMEOUT MODAL ---
  void _showTimeoutModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();

        return Container(
          padding: const EdgeInsets.all(24),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Request Time-Out', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Select team taking the time-out:', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: engine.homeTimeOuts >= 2
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(modalContext);
                              await context.read<MatchEngine>().takeTimeout("Home");
                            },
                      child: Text('Home (${engine.homeTimeOuts}/2)', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: engine.awayTimeOuts >= 2
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(modalContext);
                              await context.read<MatchEngine>().takeTimeout("Away");
                            },
                      child: Text('Away (${engine.awayTimeOuts}/2)', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
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
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();

        return Container(
          padding: const EdgeInsets.all(24),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Substitution', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Select team making a substitution:', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: !engine.canTakeSub("Home")
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(modalContext);
                              _showPlayerOffModal(context, "Home");
                            },
                      child: Text('Home (${engine.homeSubCount}/6)', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: !engine.canTakeSub("Away")
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(modalContext);
                              _showPlayerOffModal(context, "Away");
                            },
                      child: Text('Away (${engine.awaySubCount}/6)', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        );
      },
    );
  }

  // --- SUB STEP 2: PICK PLAYER OFF (ON COURT) ---
  void _showPlayerOffModal(BuildContext context, String team) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();
        final onCourt = engine.getOnCourtPlayers(team);

        return Container(
          padding: const EdgeInsets.all(24),
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$team Team - Select Player Coming OFF', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
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
                    Player p = onCourt[index];
                    int subCount = engine.getSubCountForPlayer(team, p.number);
                    bool isExhausted = engine.isPositionExhausted(team, p.number);
                    Player? lockedPartner = engine.getLockedSubPartner(team, p.number);

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
                          Text('#${p.number} ${p.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                          Text(statusLabel, style: TextStyle(color: subCount == 1 ? Colors.amberAccent : (isExhausted ? Colors.redAccent[100] : Colors.white54), fontSize: 10)),
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
  void _showLockedSubConfirmationModal(BuildContext context, String team, Player playerOff, Player lockedPlayerOn) {
    // 1. Capture the engine safely using the main screen's context *before* opening the sheet
    final engine = context.read<MatchEngine>();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
                  Text('Confirm Re-entry', style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Subbing off #${playerOff.number} (${playerOff.name}). Under FIVB rules, original starter #${lockedPlayerOn.number} (${lockedPlayerOn.name}) will automatically re-enter.',
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
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(modalContext);
                        
                        // 2. Use the pre-captured engine reference safely
                        await engine.executeSubstitution(team, playerOff.number, lockedPlayerOn.number);
                      },
                      child: Text('Confirm #${lockedPlayerOn.number} ON', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
  void _showPlayerOnModal(BuildContext context, String team, int playerOffNum) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF222222),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (modalContext) {
        final engine = modalContext.watch<MatchEngine>();
        final bench = engine.getEligibleBenchPlayers(team, playerOffNum);

        return Container(
          padding: const EdgeInsets.all(24),
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$team Team - Select Player Coming ON for #${playerOffNum}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Expanded(
                child: bench.isEmpty
                    ? const Center(child: Text('No eligible bench players', style: TextStyle(color: Colors.white54)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 2.2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: bench.length,
                        itemBuilder: (context, index) {
                          Player p = bench[index];
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[800],
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            onPressed: () async {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(modalContext);
                              await context.read<MatchEngine>().executeSubstitution(team, playerOffNum, p.number);
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('#${p.number} ${p.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                                Text(p.position, style: const TextStyle(color: Colors.white54, fontSize: 10)),
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