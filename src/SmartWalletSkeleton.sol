// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Interface for ERC20 tokens
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

// Simplified EntryPoint interface for UserOperation handling
interface IEntryPoint {
    function handleOps(UserOperation[] calldata ops, address payable beneficiary) external;
}

// UserOperation struct as per EIP-4337
struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

// SmartWallet contract implementing basic EIP-4337 functionality
contract SmartWallet {
    // State variables
    address public immutable owner; // Wallet owner
    uint256 public nonce; // Nonce to prevent replay attacks
    address public immutable entryPoint; // EntryPoint contract address

    // Events
    event Executed(address indexed to, uint256 value, bytes data);
    event BatchExecuted(address[] tos, uint256[] values, bytes[] datas);

    // Constructor to set owner and EntryPoint
    constructor(address _owner, address _entryPoint) {
        owner = _owner;
        entryPoint = _entryPoint;
        nonce = 0;
    }

    // Modifier to restrict access to EntryPoint
    modifier onlyEntryPoint() {
        require(msg.sender == entryPoint, "Only EntryPoint can call");
        _;
    }

    // Fallback function to receive ETH
    receive() external payable {}

    // Validate UserOperation (simplified signature check)
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external onlyEntryPoint returns (uint256 validationData) {
        // Ensure correct sender and nonce
        require(userOp.sender == address(this), "Invalid sender");
        require(userOp.nonce == nonce, "Invalid nonce");

        // Simplified signature check: assume signature is valid if it matches expected format
        // In production, use ECDSA or custom logic to verify userOp.signature
        require(userOp.signature.length > 0, "Invalid signature");

        // Increment nonce to prevent replay
        nonce++;

        // Pay EntryPoint for missing funds (if any)
        if (missingAccountFunds > 0) {
            (bool success, ) = payable(msg.sender).call{value: missingAccountFunds}("");
            require(success, "Failed to pay EntryPoint");
        }

        // Return 0 for valid operation (per EIP-4337)
        return 0;
    }

    // Execute a single transaction
    function execute(address to, uint256 value, bytes calldata data) external onlyEntryPoint {
        // Perform the call
        (bool success, ) = to.call{value: value}(data);
        require(success, "Execution failed");
        emit Executed(to, value, data);
    }

    // Bonus: Batch execute multiple transactions
    function executeBatch(address[] calldata tos, uint256[] calldata values, bytes[] calldata datas) external onlyEntryPoint {
        require(tos.length == values.length && values.length == datas.length, "Array length mismatch");
        for (uint256 i = 0; i < tos.length; i++) {
            (bool success, ) = tos[i].call{value: values[i]}(datas[i]);
            require(success, "Batch execution failed");
        }
        emit BatchExecuted(tos, values, datas);
    }
}

// Paymaster contract to sponsor gas fees
contract Paymaster {
    // State variables
    address public immutable entryPoint; // EntryPoint contract address
    IERC20 public token; // ERC20 token for gas payments (bonus feature)
    address public owner; // Paymaster owner
    uint256 public constant GAS_FEE = 0.01 ether; // Fixed gas fee in tokens (for simplicity)

    // Events
    event GasSponsored(address indexed wallet, uint256 amount);
    event TokenFeeCharged(address indexed wallet, uint256 amount);

    // Constructor to set EntryPoint, token, and owner
    constructor(address _entryPoint, address _token) {
        entryPoint = _entryPoint;
        token = IERC20(_token);
        owner = msg.sender;
    }

    // Modifier to restrict access to EntryPoint
    modifier onlyEntryPoint() {
        require(msg.sender == entryPoint, "Only EntryPoint can call");
        _;
    }

    // Validate Paymaster operation and sponsor gas
    function validatePaymasterUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        // Check if Paymaster can sponsor (e.g., wallet has enough tokens)
        require(token.balanceOf(userOp.sender) >= GAS_FEE, "Insufficient token balance");

        // Charge token fee (bonus feature)
        bool success = token.transferFrom(userOp.sender, address(this), GAS_FEE);
        require(success, "Token transfer failed");

        // Log sponsorship
        emit TokenFeeCharged(userOp.sender, GAS_FEE);
        emit GasSponsored(userOp.sender, maxCost);

        // Return empty context and 0 for valid operation
        return (new bytes(0), 0);
    }

    // Withdraw tokens (for owner)
    function withdrawTokens(address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner");
        require(token.transfer(to, amount), "Token transfer failed");
    }

    // Receive ETH (in case EntryPoint refunds)
    receive() external payable {}
}