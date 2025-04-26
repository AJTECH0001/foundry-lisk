// SPDX-License-Identifier: MIT  
pragma solidity ^0.8.20;  

import "forge-std/Test.sol";  
import "../src/LotteryGame.sol";  

contract LotteryGameTest is Test {  
    LotteryGame game;  
    address player1;  
    address player2;  
    
    function setUp() public {  
        game = new LotteryGame();  
        player1 = makeAddr("player1");  
        player2 = makeAddr("player2");  

        // Fund test accounts with ether  
        vm.deal(player1, 1 ether);  
        vm.deal(player2, 1 ether);  
    }  

    function testRegisterWithCorrectAmount() public {  
        vm.prank(player1);  
        game.register{value: 0.02 ether}();  
        
        LotteryGame.Player memory player = game.players(player1);  
        
        assertEq(player.attempts, 0);  
        assertTrue(player.active);  
    }  

    function testRegisterWithIncorrectAmount() public {  
        vm.prank(player1);  
        vm.expectRevert("Incorrect ETH amount");  
        game.register{value: 0.01 ether}();  
    }  

    function testRegisterTwiceNotAllowed() public {  
        vm.prank(player1);  
        game.register{value: 0.02 ether}();  

        vm.expectRevert("Player already registered");  
        game.register{value: 0.02 ether}();  
    }  

    function testMakeValidGuess() public {  
        vm.prank(player1);  
        game.register{value: 0.02 ether}();  

        uint256 randomGuess = 5; // Use a valid guess for this test  
        game.guessNumber(randomGuess);  
        
        LotteryGame.Player memory player = game.players(player1);  
        assertEq(player.attempts, 1);  
    }  

    function testMakeGuessOutOfRange() public {  
        vm.prank(player1);  
        game.register{value: 0.02 ether}();  

        vm.expectRevert("Guess must be between 1 and 9");  
        game.guessNumber(0);  
        
        vm.expectRevert("Guess must be between 1 and 9");  
        game.guessNumber(10);  
    }  

    function testMaxAttemptsLimit() public {  
        vm.prank(player1);  
        game.register{value: 0.02 ether}();  
        
        game.guessNumber(5);  
        game.guessNumber(6);  

        vm.expectRevert("Max attempts reached");  
        game.guessNumber(7);  
    }  

    function testDistributePrizesNoWinners() public {  
        vm.expectRevert("No winners to distribute prizes to");  
        game.distributePrizes();  
    }  

    function testWinnersReceivePrizes() public {  
        vm.prank(player1);  
        game.register{value: 0.02 ether}();  

        vm.prank(player2);  
        game.register{value: 0.02 ether}();  

        vm.prank(player1);  
        game.guessNumber(5); // Assuming 5 is the right guess  
        
        vm.prank(player2);  
        game.guessNumber(5); // Assuming 5 is the right guess  
        
        game.distributePrizes();  

        address[] memory winners = game.getPrevWinners();  
        assertEq(winners.length, 2);  
    }  
}  