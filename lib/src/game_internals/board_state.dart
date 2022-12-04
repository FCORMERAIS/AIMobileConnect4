
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:game_template/src/game_internals/board_setting.dart';
import 'package:game_template/src/game_internals/tile.dart';

import '../style/palette.dart';

enum TileOwner {
  blank,
  player,
  ai
}

class BoardState extends ChangeNotifier {
  final BoardSetting boardSetting;
  List<List<int>> boardGameForAI = [[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]];
  final List<Tile> playerTaken = [];
  final List<Tile> aiTaken = [];
  List<Tile> winTiles = [];

  final ChangeNotifier playerWon = ChangeNotifier();

  String noticeMessage = "";
  bool _isLocked = false;

  BoardState({required this.boardSetting});

  void clearBoard() {
    playerTaken.clear();
    aiTaken.clear();
    winTiles.clear();
    boardGameForAI = [[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]];
    noticeMessage = "";
    _isLocked = false;
    notifyListeners();
  }

  Color tileColor(Tile tile) {
    if (winTiles.contains(tile)) {
      return Colors.green;
    } else if (getTileOwner(tile) == TileOwner.player) {
      return Colors.amber;
    } else if (getTileOwner(tile) == TileOwner.ai) {
      return Colors.redAccent;
    } else {
      return Palette().backgroundPlaySession;
    }
  }
  
  Future<void> makeMove(Tile tile) async {
    assert(!_isLocked);
    Tile? newTile = evaluateMove(tile);
    if (newTile == null) {
      noticeMessage = "Move not possible, try again";
      notifyListeners();
      return;
    }else {
      boardGameForAI[newTile.row-1][newTile.col-1] = 1;
      noticeMessage = "COL : $boardGameForAI";
      notifyListeners();
    }
    noticeMessage = "COL : ${newTile.col}  \nROW : ${newTile.row}";
    notifyListeners();
    playerTaken.add(newTile);
    _isLocked = true;

    bool didPlayerWin = checkWin(newTile);
    if (didPlayerWin == true) {
      playerWon.notifyListeners();
      notifyListeners();
      return;
    }
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    // make the AI move
    Tile? aiTile = makeAiMove();
    if (aiTile == null) {
      noticeMessage = "No moves left, reset to play again";
      notifyListeners();
      return;
    }else {
      noticeMessage = "COL : ${aiTile.col}  \nROW : ${aiTile.row}";
      notifyListeners();
      boardGameForAI[aiTile.row-1][aiTile.col-1] = 2;
    }
    aiTaken.add(aiTile);
    bool didAiWin = checkWin(aiTile);
    if (didAiWin == true) {
      noticeMessage = "You lost, reset to play again";
      notifyListeners();
      return;
    }
    _isLocked = false;
    notifyListeners();
  }

  Tile? evaluateMove(Tile tile) {
    for (var bRow = 1; bRow < boardSetting.rows + 1; bRow++) {
      var evalTile = Tile(col: tile.col, row: bRow);
      if (getTileOwner(evalTile) == TileOwner.blank) {
        return evalTile;
      }
    }
    return null;
  }

  Tile? makeAiMove() {
    List<Tile> available = [];
    for (var row = 1; row < boardSetting.rows + 1; row++) {
      for (var col = 1; col < boardSetting.cols + 1; col++) {
        Tile tile = Tile(col: row-1, row: col+1);
        if (getTileOwner(tile) == TileOwner.blank) {
          available.add(tile);
        }
      }
    }

    if (available.isEmpty) { return null; }
    Object col = minimax(boardGameForAI, 5, -10000000000000, 10000000000000, true)[0] ;
    int row = getNextOpenRow(boardGameForAI, col as int);
    Tile aiTile = Tile(col: col+1, row: row+1);
    return aiTile;
  }

  List<List<int>> returnboard(List<List<int>>boardP4) {
    List<List<int>> res = [boardP4[5],boardP4[4],boardP4[3],boardP4[2],boardP4[1],boardP4[0]];
    return res;
  }

  List<int> getValidLocations(List<List<int>> board) {
    List<int> validLocations = [];
    for (var col = 0; col < 7; col++) {
      if (isValidLocation(board, col)) {
        validLocations.add(col);
      }
    }
    return validLocations;
  }
  
  bool isValidLocation(List<List<int>>board,int col){
	  return board[5][col] == 0;
  }

  bool isTerminalNode(List<List<int>> board) {
	  return (winningMove(board, 1) || winningMove(board, 2) || getValidLocations(board).isEmpty);
  }

    
  bool winningMove(List<List<int>> board,int piece) {
    // Check horizontal locations for win
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 6; r++) {
        if (board[r][c] == piece && board[r][c+1] == piece && board[r][c+2] == piece && board[r][c+3] == piece) {
          return true;
        }
      }
    }

    // Check vertical locations for win
    for (var c = 0; c < 7; c++) {
      for (var r = 0; r < 3; r++) {
        if (board[r][c] == piece && board[r+1][c] == piece && board[r+2][c] == piece && board[r+3][c] == piece) {
          return true;
        }
      }
    }
    // Check positively sloped diaganols
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 3; r++) {
        if (board[r][c] == piece && board[r+1][c+1] == piece && board[r+2][c+2] == piece && board[r+3][c+3] == piece) {
          return true;
        }
      }
    }
    // Check negatively sloped diaganols
    for (var c = 0; c < 4; c++) {
      for (var r = 3; r < 6; r++) {
        if (board[r][c] == piece && board[r-1][c+1] == piece && board[r-2][c+2] == piece && board[r-3][c+3] == piece) {
          return true;
        }
      }
    }
    return false;
  }

  int centerCount(List<List<int>> board, int piece) {
    int res = 0;
    for (var i = 0; i < 6; i++) {
      if (board[i][3] == piece ) {
        res++;
      }
    }
    return res;
  }
    
  int evaluateWindow(List<int> window,int piece){
    int score = 0;
    int oppPiece = 1;
    if (piece == 1){
      oppPiece = 2;
    }
    if (findOccurrences(piece,window) == 4) {
      score += 100;
    }
    if (findOccurrences(piece,window) == 3 && findOccurrences(0,window) == 1){
      score += 5;
    }
    if (findOccurrences(piece,window) == 2 && findOccurrences(0,window) == 2){
      score += 2;
    }
    if (findOccurrences(oppPiece,window) == 3 && findOccurrences(0,window) == 1){
      score -= 4;
    }
    return score;
  }

  int findOccurrences(int piece, List<int> board) {
    int res = 0;
    for (var i = 0; i < 4; i++) {
      if (piece == board[i]) {
        res++;
      }
    }
    return res;
  }

  List<int> getVerticalWindow(int index, List<List<int>> board) {
    List<int> res = [];
    for (int i = 5; i >= 0; i--) {
      res.add(board[i][index]);
    }
    return res;
  }

  int scorePosition(List<List<int>> board, int piece) {
    int score = 0;

    // Score center column
    score += centerCount(board,piece) * 3;

    // Score Horizontal
    for (int r = 0; r < 6; r++) {
      List<int> rowArray = board[r];
      for (int c = 0; c<4;c++) {
        List<int> window = [];
        for (int i = 0;i<4;i++) {
          window.add(rowArray[c+i]);
        }
        score += evaluateWindow(window, piece);
      }
    }

    // Score Vertical
    for (var c = 0; c < 7; c++) {
      List<int> colArray = getVerticalWindow(c, board);
      for (int r = 0 ; r< 3; r++) {
        List<int> window = [];
        for (int i = 0;i<4;i++) {
          window.add(colArray[r+i]);
        }
        score += evaluateWindow(window, piece);
      }
    }

    // Score posiive sloped diagonal

    for (int r = 0; r < 3; r++) {
      for(int c = 0 ; c < 4 ; c++) {
        List<int> window = [];
        for (int i = 0; i < 4; i++) {
          window.add(board[r+i][c+i]);
        }
        score += evaluateWindow(window, piece);
      }
    }

    for (int r = 0 ; r<3;r++) {
      for (int c = 0; c < 4; c++) {
        List<int> window = [];
        for (int i = 0; i < 4; i++) {
          window.add(board[r+3-i][c+i]);
        }
        score += evaluateWindow(window, piece);
      }
    }
  return score;
  }

  int getNextOpenRow(List<List<int>> board, int col) {
    for (int r = 0 ; r<6 ; r++) {
      if (board[r][col] == 0) {
        return r;
      }
    }
    return 5;
  }

  List<List<int>> dropPiece(List<List<int>> board, int row, int col , int piece) {
    board[row][col] = piece;
    return board;
  }

  List<List<int>> cloneBoard(List<List<int>> board) {
    List<List<int>> res = [];
    for (var i = 0; i < board.length; i++) {
      List<int> boardLine = [];
      for (var j = 0; j < board[i].length; j++) {
        int value = board[i][j];
        boardLine.add(value);
      }
      res.add(boardLine);
    }
    return res;
  }

  List<Object> minimax(List<List<int>>board, int depth, int alpha,int beta,bool maximizingPlayer) {
    List<int> validLocations = getValidLocations(board);
    if (depth == 5) {
      for (var i = 0; i < validLocations.length; i++) {
        List<List<int>> testWinMove = cloneBoard(board);
        int row = getNextOpenRow(board, validLocations[i]);
        testWinMove[row][validLocations[i]] = 2;
        if (winningMove(testWinMove,2)) {
          return [validLocations[i],0]; // WIN 
        }
      }
      for (var i = 0; i < validLocations.length; i++) {
        List<List<int>> testWinMove = cloneBoard(board);
        int row = getNextOpenRow(board, validLocations[i]);
        testWinMove[row][validLocations[i]] = 1;
        if (winningMove(testWinMove,1)) {
          return [validLocations[i],0]; // Stop Win Ennemie
        }
      }
    }
    bool isTerminal = isTerminalNode(board);
    if (depth == 0 || isTerminal){
      if (isTerminal) {
        if (winningMove(board, 2)){
          return [Null, 100000000000000];
        }
        else if (winningMove(board, 1)) {
          return [Null, -10000000000000];
        }
        else{ // Game is over, no more valid moves
          return [Null, 0];
        }
      }else{ // Depth is zero
        return [Null, scorePosition(board, 2)];
      }
    }
    if (maximizingPlayer){
      int value = -1000000000000000;
      final random = Random();
      int column = validLocations[random.nextInt(validLocations.length)];
      for (int i = 0; i < validLocations.length ; i++){
        int row = getNextOpenRow(board, validLocations[i]);
        List<List<int>> boardCopy =  cloneBoard(board);
        boardCopy = dropPiece(boardCopy, row, validLocations[i], 2);
        int newScore = minimax(boardCopy, depth-1, alpha, beta, false)[1] as int ;
        if (newScore > value) {
          value = newScore;
          column = validLocations[i];
        }
        if (alpha < value) {
          alpha = value;
        }
        if (alpha >= beta){
          break;
        }
      }
      return [column, value];
    }

    else{ // Minimizing player
      int value = 10000000000000000;
      final random = Random();
      int column = validLocations[random.nextInt(validLocations.length)];
      for (int i = 0 ; i<validLocations.length ; i++) {
        int row = getNextOpenRow(board, validLocations[i]);
        List<List<int>> boardCopy =  cloneBoard(board);
        dropPiece(boardCopy, row, validLocations[i], 1);
        int newScore = minimax(boardCopy, depth-1, alpha, beta, true)[1] as int;
        if (newScore < value) {
          value = newScore;
          column = validLocations[i];
        }
        if (beta > value) {
          beta = value;
        }
        if (alpha >= beta) {
          break;
        }
      }
      return [column, value];
    }
  }

  TileOwner getTileOwner(Tile tile) {
    if (playerTaken.contains(tile)) {
      return TileOwner.player;
    } else if (aiTaken.contains(tile)) {
      return TileOwner.ai;
    } else {
      return TileOwner.blank;
    }
  }

  bool checkWin(Tile playTile) {
    var takenTiles = (getTileOwner(playTile) == TileOwner.player) ? playerTaken : aiTaken;

    List<Tile>? vertical = verticalCheck(playTile, takenTiles);
    if (vertical != null) {
      winTiles = vertical;
      return true;
    }

    List<Tile>? horizontal = horizontalCheck(playTile, takenTiles);
    if (horizontal != null) {
      winTiles = horizontal;
      return true;
    }

    List<Tile>? forwardDiagonal = forwardDiagonalCheck(playTile, takenTiles);
    if (forwardDiagonal != null) {
      winTiles = forwardDiagonal;
      return true;
    }

    List<Tile>? backDiagonal = backDiagonalCheck(playTile, takenTiles);
    if (backDiagonal != null) {
      winTiles = backDiagonal;
      return true;
    }

    return false;
  }

  List<Tile>? verticalCheck(Tile playTile, List<Tile> takenTiles) {
    List<Tile> tempWinTiles = [];

    for (var row = playTile.row; row > 0; row--) {
      Tile tile = Tile(col: playTile.col, row: row);
      if (takenTiles.contains(tile)) {
        tempWinTiles.add(tile);
      } else {
        break;
      }
    }

    if (tempWinTiles.length >= boardSetting.winCondition()) {
      return tempWinTiles;
    }

    return null;
  }

  List<Tile>? horizontalCheck(Tile playTile, List<Tile> takenTiles) {
    // add the play tile to the list
    List<Tile> tempWinTiles = [playTile];

    // Look left, unless playTile is the first tile.
    // Start at playTile.col - 1
    if (playTile.col > 1) {
      for (var col = playTile.col - 1; col > 0; col--) {
        Tile tile = Tile(col: col, row: playTile.row);

        if (takenTiles.contains(tile)) {
          tempWinTiles.add(tile);
        } else {
          break;
        }
      }
    }

    // Look right, unless playTile is the last tile.
    // Start at playTile.col + 1
    if (playTile.col < boardSetting.cols) {
      for (var col = playTile.col + 1; col < boardSetting.cols + 1; col++) {
        Tile tile = Tile(col: col, row: playTile.row);

        if (takenTiles.contains(tile)) {
          tempWinTiles.add(tile);
        } else {
          break;
        }
      }
    }

    // see if tempWinTiles meets the win condition, if so it's a win
    if (tempWinTiles.length >= boardSetting.winCondition()) {
      return tempWinTiles;
    }

    return null;
  }

  List<Tile>? forwardDiagonalCheck(Tile playTile, List<Tile> takenTiles) {
    // add the play tile to the list
    List<Tile> tempWinTiles = [playTile];

    // Look left & down, unless playTile is the first tile or in row 1.
    // Start at playTile.col - 1
    if (playTile.col > 1 && playTile.row > 1) {
      // iterate to check all lower rows
      for (var i = 1; i < playTile.row + 1; i++) {
        Tile tile = Tile(col: playTile.col - i, row: playTile.row - i);

        if (takenTiles.contains(tile)) {
          tempWinTiles.add(tile);
        } else {
          break;
        }
      }
    }

    // Look right & up, unless playTile is the last tile or in top row.
    // Start at playTile.col - 1
    if (playTile.col < boardSetting.cols && playTile.row < boardSetting.rows) {
      // iterate to check all upper rows. loop until hitting the top.
      // so from (top - playTile.row) times.
      for (var i = 1; i < (boardSetting.rows + 1) - playTile.row; i++) {
        Tile tile = Tile(col: playTile.col + i, row: playTile.row + i);
        if (takenTiles.contains(tile)) {
          tempWinTiles.add(tile);
        } else {
          break;
        }
      }
    }

    // see if tempWinTiles meets the win condition, if so it's a win
    if (tempWinTiles.length >= boardSetting.winCondition()) {
      return tempWinTiles;
    }

    return null;
  }

  List<Tile>? backDiagonalCheck(Tile playTile, List<Tile> takenTiles) {
    // add the play tile to the list
    List<Tile> tempWinTiles = [playTile];

    // Look left & up, unless playTile is the first tile or in top row.
    if (playTile.col > 1 && playTile.row < boardSetting.rows) {
      // iterate to check all upper rows
      for (var i = 1; i < (boardSetting.rows + 1) - playTile.row; i++) {
        Tile tile = Tile(col: playTile.col - i, row: playTile.row + i);

        if (takenTiles.contains(tile)) {
          tempWinTiles.add(tile);
        } else {
          break;
        }
      }
    }

    // Look right & down, unless playTile is the last tile or bottom row.
    if (playTile.col < boardSetting.cols && playTile.row > 1) {
      // iterate to check all lower rows. loop until hitting the bottom.
      for (var i = 1; i < playTile.row + 1; i++) {
        Tile tile = Tile(col: playTile.col + i, row: playTile.row - i);
        if (takenTiles.contains(tile)) {
          tempWinTiles.add(tile);
        } else {
          break;
        }
      }
    }

    // see if tempWinTiles meets the win condition, if so it's a win
    if (tempWinTiles.length >= boardSetting.winCondition()) {
      return tempWinTiles;
    }

    return null;
  }

}