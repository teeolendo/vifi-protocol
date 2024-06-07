// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts@4.9.3/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.3/access/Ownable.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "mUSDC") {
        _mint(msg.sender, 1000000000 * 10**18); // Mint 1 million tokens for testing
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
        require(_dao != address(0), "Invalid DAO address");
        dao = _dao;
    }

    function setCBrate(uint256 _CBrate) external onlyDAO {
        CBrate = _CBrate;
    }

    function convertVUSDToTokens(uint256 vUSDAmount, address destination) public {
        vUSD.burn(msg.sender, vUSDAmount);
        vRT.mint(destination, vUSDAmount);
        vTTD.mint(destination, (vUSDAmount * CBrate) / 100); // Adjusted for 2 decimal places
    }

    function convertTokensToVUSD(uint256 vRTAmount, address destination) public {
        uint256 burnCBrate = getBurnCBrate();
        uint256 vTTDAmount = (vRTAmount * burnCBrate) / 100; // Adjusted for 2 decimal places

        require( vTTDAmount > vTTD.balanceOf(msg.sender), "Not Enough, vTTD");

        //require(( vTTDAmount * 100 ) / burnCBrate == vRTAmount, "Amounts mismatch");

        vTTD.burn(msg.sender, vTTDAmount);
        vRT.burn(msg.sender, vRTAmount);
        vUSD.mint(destination, vRTAmount);
    }

    function getBurnCBrate() public view returns (uint256) {
        return (vTTD.totalSupply() * 100) / vRT.totalSupply(); // Adjusted for 2 decimal places
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

    function setVarq(address _varq) public onlyOwner {
        require(_varq != address(0), "Invalid VARQ address");
        varq = VARQ(_varq);
        // Ensure the new varq is properly initialized and set as a controller
        varq.initialize(address(vUSD), address(vTTD), address(vRT));
        varq.setDAO(address(this));
        vUSD.setController(address(varq), true);
        vTTD.setController(address(varq), true);
        vRT.setController(address(varq), true);
    }

    function setVirtualizer(address _virtualizer) public onlyOwner {
        require(_virtualizer != address(0), "Invalid Virtualizer address");
        virtualizer = Virtualizer(_virtualizer);
        // Ensure the new virtualizer is set as a controller
        vUSD.setController(address(virtualizer), true);
    }
}
