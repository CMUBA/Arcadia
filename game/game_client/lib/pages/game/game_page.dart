import 'dart:math';

import 'package:bonfire/bonfire.dart';
import 'package:bonfire/map/util/world_map_reader.dart';
import 'package:bonfire_multiplayer/components/my_player/bloc/my_player_bloc.dart';
import 'package:bonfire_multiplayer/components/my_player/my_player.dart';
import 'package:bonfire_multiplayer/components/my_remote_player/my_remote_player.dart';
import 'package:bonfire_multiplayer/data/game_event_manager.dart';
import 'package:bonfire_multiplayer/dummy/battle.dart';
import 'package:bonfire_multiplayer/dummy/chest.dart';
import 'package:bonfire_multiplayer/dummy/player_battle_list.dart';
import 'package:bonfire_multiplayer/event/battle_event.dart';
import 'package:bonfire_multiplayer/main.dart';
import 'package:bonfire_multiplayer/npc/critter.dart';
import 'package:bonfire_multiplayer/npc/wizard.dart';
import 'package:bonfire_multiplayer/pages/game/game_route.dart';
import 'package:bonfire_multiplayer/pages/home/home_page.dart';
import 'package:bonfire_multiplayer/pages/home/home_route.dart';
import 'package:bonfire_multiplayer/util/extensions.dart';
import 'package:bonfire_multiplayer/util/player_skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:shared_events/shared_events.dart';

import '../../event/random_event_manager.dart';
import '../../interface/my_game_interface.dart';

class GamePage extends StatefulWidget {
  static const routeName = '/game';

  late JoinMapEvent event;
  static const tileSize = 16.0;

  GamePage({super.key}){
    event = Get.arguments as JoinMapEvent;
  }

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with TickerProviderStateMixin {
  late GameEventManager _eventManager;
  late BonfireGameInterface game;
  late AnimationController _controller;

  bool _isLeaderboardExpanded = false;
  String _currentRandomEvent = '';
  late BattleLogBloc logBloc;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    super.initState();
  }

  @override
  void dispose() {
    _eventManager.removeOnPlayerState(_onPlayerState);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    logBloc = BlocProvider.of<BattleLogBloc>(context);
    return BlocProvider(
      create: (context) => MyPlayerBloc(
        context.read(),
        widget.event.state.id,
        Vector2(widget.event.state.position.toVector2().x + 1, widget.event.state.position.toVector2().y + 1),
        widget.event.map,
      ),
      child: Container(
        color: Colors.black,
        child: FadeTransition(
          opacity: _controller,
          child: BonfireWidget(
            // showCollisionArea: kDebugMode,
            // debugMode: kDebugMode,
            // collisionAreaColor: Colors.red.withOpacity(.5),
            interface: MyGameInterface(),
            map: WorldMapByTiled(
              WorldMapReader.fromNetwork(
                Uri.parse('http://$address:9090/${widget.event.map.path}'),
              ),
              objectsBuilder: {

              }
            ),
            playerControllers: [
              Keyboard(
                config: KeyboardConfig(
                  enableDiagonalInput: false,
                  directionalKeys: [
                    KeyboardDirectionalKeys.wasd(),
                    KeyboardDirectionalKeys.arrows()
                  ]
                ),
              ),
              Joystick(directional: JoystickDirectional(
                enableDiagonalInput: false,
              ))
            ],
            player: _getPlayer(widget.event.state),
            components: [
              ..._getComponents(widget.event, context),
              SpikesComponent(),
              //对话
              //Wizard(Vector2(100, 200), state: widget.event.state),
              //跟随npc
              Critter(Vector2(150, 200)),
              Chest(Vector2(150, 60)),
              Chest(Vector2(70, 60)),
              Chest(Vector2(100, 70)),
              Chest(Vector2(130, 90)),
              // Chest(Vector2(150, 100)),
              Battle(Vector2(150, 100), widget.event.players.toList()),
              Battle(Vector2(200, 100), widget.event.players.toList()),
              Battle(Vector2(250, 100), widget.event.players.toList()),
              BattleList(Vector2(0, 0), logBloc)
            ],
            cameraConfig: CameraConfig(
              initialMapZoomFit: InitialMapZoomFitEnum.fitHeight,
              moveOnlyMapArea: true,
            ),
            overlayBuilderMap: {
              'leaderboardButton': (context, game) {
                return _buildLeaderboardButton(context, game, context.read<MyPlayerBloc>());
              }, // 新增
            },
            initialActiveOverlays: const [
              'leaderboardButton',
            ],
            onReady: _onReady,
          ),
        ),
      ),
    );
  }

  // 新增方法
  Widget _buildLeaderboardButton(BuildContext context, BonfireGameInterface game, MyPlayerBloc b) {
    return Positioned(
      top: kToolbarHeight,
      right: 10,
      child: _isLeaderboardExpanded ? _buildLeaderboardPanel(b) : IconButton(
        onPressed: () {
          if(mounted) {
            setState(() {
              _isLeaderboardExpanded = !_isLeaderboardExpanded;
            });
          }
        },
        icon: Container(
            alignment: Alignment.center,
            padding: EdgeInsets.all(8),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: const Icon(Icons.signal_cellular_alt))
      ),
    );
  }

  Widget _buildLeaderboardPanel(MyPlayerBloc bloc) {
    return Material(type: MaterialType.card, child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isLeaderboardExpanded ? 200 : 0,
        height: _isLeaderboardExpanded ? 300 : 0,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Stack(alignment: Alignment.topRight, children: [
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('当前状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                )
              ]),
              IconButton(onPressed: () {
                if(mounted) {
                  setState(() {
                    _isLeaderboardExpanded = !_isLeaderboardExpanded;
                  });
                }
              }, icon: const Icon(Icons.clear))
            ]),
            Expanded(child: SingleChildScrollView(child: BlocBuilder<MyPlayerBloc, MyPlayerState>(bloc: bloc, builder: (_, state){
              return Column(children: [
                Text("${state.characterState.toString()}")
              ]);
            })))
          ],
        )
    ));
  }

  // Adds player in the game with ack informations
  Player _getPlayer(ComponentStateModel state) {
    return MyPlayer(
      block: logBloc,
      position: state.position.toVector2(),
      skin: PlayerSkin.fromName(state.properties['skin']),
      initDirection: state.lastDirection?.toDirection(),
      name: state.name,
      speed: state.speed,
    );
  }

  // Adds remote plasyers with ack informations
  List<GameComponent> _getComponents(JoinMapEvent event, BuildContext context) {
    final players = event.players.toList();
    return List.generate(players.length, (index) {
      return _createRemotePlayerWithIndex(players[index], index);
    });
  }

  int lastServerRemotes = 0;

  // When the game is ready init listeners:
  // PLAYER_LEAVE: When some player leave remove it of game.
  // PLAYER_JOIN: When some player enter adds it in the game.
  void _onReady(BonfireGameInterface game) {
    this.game = game;
    _eventManager = context.read();
    _eventManager.onDisconnect(() {
      Get.offAllNamed(HomePage.routeName);
    });

    _eventManager.onPlayerState(
      _onPlayerState,
    );
    _eventManager.onEvent<JoinMapEvent>(
      EventType.JOIN_MAP.name,
      _onAckJoint,
    );
    Future.delayed(const Duration(milliseconds: 100), _controller.forward);

    // Future.delayed(const Duration(seconds: 1), () => _randomlyAssignTriggers(game));
  }

  void _onPlayerState(Iterable<ComponentStateModel> serverPlayers) {
    if (lastServerRemotes != serverPlayers.length) {
      final remotePlayers = game.query<MyRemotePlayer>();
      // adds RemotePlayer if no exist in the game but exist in server
      for (var serverPlayer in serverPlayers) {
        if (serverPlayer.id != widget.event.state.id) {
          final contain = remotePlayers.any(
            (element) => element.id == serverPlayer.id,
          );
          if (!contain) {
            game.add(
              _createRemotePlayer(serverPlayer),
            );
          }
        }
      }

      // remove RemotePlayer if no exist in server
      for (var player in remotePlayers) {
        final contain = serverPlayers.any(
          (element) => element.id == player.id,
        );
        if (!contain) {
          player.removeFromParent();
        }
      }
      lastServerRemotes = serverPlayers.length;
    }
  }

  GameComponent _createRemotePlayerWithIndex(ComponentStateModel state, int index) {
    return MyRemotePlayer(
      logBlock: logBloc,
      position: Vector2(state.position.toVector2().x + index, state.position.toVector2().y + index),
      initDirection: state.lastDirection?.toDirection(),
      skin: PlayerSkin.fromName(state.properties['skin']),
      eventManager: context.read(),
      id: state.id,
      name: state.name,
      speed: state.speed,
    );
  }

  GameComponent _createRemotePlayer(ComponentStateModel state) {
    return MyRemotePlayer(
      logBlock: logBloc,
      position: state.position.toVector2(),
      initDirection: state.lastDirection?.toDirection(),
      skin: PlayerSkin.fromName(state.properties['skin']),
      eventManager: context.read(),
      id: state.id,
      name: state.name,
      speed: state.speed,
    );
  }

  void _onAckJoint(JoinMapEvent event) {
    Get.offAllNamed(GamePage.routeName, arguments: event);
  }
}
