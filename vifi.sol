// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.3/access/Ownable.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1 million tokens for testing
    }
}

contract Virtualizer {
    IERC20 public mUSDC;
    vToken public vUSD;

    constructor(address _mUSDC, address _vUSD) {
        mUSDC = IERC20(_mUSDC);
        vUSD = vToken(_vUSD);
    }

    function wrap(uint256 amount) public {
        mUSDC.transferFrom(msg.sender, address(this), amount);
        vUSD.mint(msg.sender, amount);
    }

    function unwrap(uint256 amount) public {
        vUSD.burn(msg.sender, amount);
        mUSDC.transfer(msg.sender, amount);
    }
}

contract vToken is ERC20, Ownable {
    mapping(address => bool) private _controllers;

    modifier onlyController() {
        require(_controllers[msg.sender], "Not a controller");
        _;
    }

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function setController(address controller, bool isController) public onlyOwner {
        _controllers[controller] = isController;
    }

    function mint(address to, uint256 amount) external onlyController {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyController {
        _burn(from, amount);
    }
}

contract VARQ is Ownable {
    vToken public vUSD;
    vToken public vTTD;
    vToken public vRT;
    uint256 public CBrate;
    address public dao;

    modifier onlyDAO() {
        require(msg.sender == dao, "Only DAO can call this");
        _;
    }

    function initialize(address _vUSD, address _vTTD, address _vRT) external onlyOwner {
        vUSD = vToken(_vUSD);
        vTTD = vToken(_vTTD);
        vRT = vToken(_vRT);
    }

    function setDAO(address _dao) external onlyOwner {
        require(dao == address(0), "DAO already set");
        dao = _dao;
    }

    function setCBrate(uint256 _CBrate) external onlyDAO {
        CBrate = _CBrate;
    }

    function convertVUSDToTokens(uint256 vUSDAmount) public {
        vUSD.burn(msg.sender, vUSDAmount);
        vRT.mint(msg.sender, vUSDAmount);
        vTTD.mint(msg.sender, vUSDAmount * CBrate);
    }

    function convertTokensToVUSD(uint256 vTTDAmount, uint256 vRTAmount) public {
        require(vTTDAmount / CBrate == vRTAmount, "Amounts mismatch");
        vTTD.burn(msg.sender, vTTDAmount);
        vRT.burn(msg.sender, vRTAmount);
        vUSD.mint(msg.sender, vRTAmount);
    }
}

contract ViFi_DAO is Ownable {
    vToken public vUSD;
    vToken public vTTD;
    vToken public vRT;

    VARQ public varq;
    Virtualizer public virtualizer;

    constructor(address _mUSDCAddress) {
        vUSD = new vToken("Virtual USD", "vUSD");
        vTTD = new vToken("Virtual Trinidad Tobago Dollars", "vTTD");
        vRT = new vToken("Virtual Reserve Token", "vRT");

        varq = new VARQ();
        virtualizer = new Virtualizer(_mUSDCAddress, address(vUSD));

        vUSD.setController(address(virtualizer), true);

        vUSD.setController(address(varq), true);
        vTTD.setController(address(varq), true);
        vRT.setController(address(varq), true);

        // Post-initialization to set up the DAO address correctly
        varq.initialize(address(vUSD), address(vTTD), address(vRT));
        varq.setDAO(address(this));
    }

    function setCBrate(uint256 _CBrate) public onlyOwner {
        varq.setCBrate(_CBrate);
    }
}
