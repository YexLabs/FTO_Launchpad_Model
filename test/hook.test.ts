import { expect } from "chai";
import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { YexFTOFactory, YexFTOFacade, USDT, UniswapV2Factory, UniswapV2Router, CustomHook } from "../typechain";

describe("YexFTOPair and CustomHook", function () {
    let yexFTOFactory: YexFTOFactory;
    let yexFTOFacade: YexFTOFacade;
    let usdt: USDT;
    let uniswapV2Factory: UniswapV2Factory;
    let uniswapV2Router: UniswapV2Router;
    let customHook: CustomHook;
  
    let owner: SignerWithAddress, addr1: SignerWithAddress, addr2: SignerWithAddress, addr3: SignerWithAddress;

    beforeEach(async function () {
        [owner, addr1, addr2, addr3] = await ethers.getSigners();

        // YexFTOFactory
        const YexFTOFactory = await ethers.getContractFactory("YexFTOFactory");
        yexFTOFactory = (await YexFTOFactory.deploy()) as YexFTOFactory;
        await yexFTOFactory.deployed();

        // YexFTOFacade
        const YexFTOFacade = await ethers.getContractFactory("YexFTOFacade");
        yexFTOFacade = (await YexFTOFacade.deploy(yexFTOFactory.address)) as YexFTOFacade;
        await yexFTOFacade.deployed();

        // USDT
        const USDT = await ethers.getContractFactory("USDT");
        usdt = (await USDT.deploy()) as USDT;
        await usdt.deployed();

        // UniswapV2Factory
        const UniswapV2Factory = await ethers.getContractFactory("UniswapV2Factory");
        uniswapV2Factory = (await UniswapV2Factory.deploy(owner.address)) as UniswapV2Factory;
        await uniswapV2Factory.deployed();

        const UniswapV2Router = await ethers.getContractFactory("UniswapV2Router02");
        uniswapV2Router = (await UniswapV2Router.deploy(uniswapV2Factory.address, usdt.address)) as UniswapV2Router;
        await uniswapV2Router.deployed();

        const initialVestingPercentage = 8000; // 80%
        const initialVestingPeriod = 5; // 5 secs
        
		const CustomHook = await ethers.getContractFactory("CustomHook"); 
		customHook = (await CustomHook.deploy(yexFTOFactory.address, initialVestingPercentage, initialVestingPeriod)) as CustomHook;
		await customHook.deployed(); 

        console.log("yexFTOFactory address: ", yexFTOFactory.address);
        console.log("USDT address: ", usdt.address);
        console.log("UniswapV2Factory address: ", uniswapV2Factory.address);
        console.log("UniswapV2Router address: ", uniswapV2Router.address);
        console.log("CustomHook address: ", customHook.address);
    });
    it("should entire a test", async function () {

        //1. Token launch
    	await yexFTOFactory.addRaisedToken(usdt.address);

    	const raisedToken = usdt.address;
        const name = "TestToken";
        const symbol = "TT";

        const amount = ethers.utils.parseUnits("1000000000", 18);
        const poolHandler = uniswapV2Router.address;
        const raisingCycle = 12; // 12 seconds

        await customHook.tokenLaunch(
            raisedToken,
            name,
            symbol,
            amount,
            poolHandler,
            raisingCycle
        );

        console.log("Token launch successful");

        const [dRaisedToken, dLaunchedToken] = await customHook.getTokenPair();

        expect(dRaisedToken).to.be.properAddress;
        expect(dLaunchedToken).to.be.properAddress;

        //2. distribute USDT and deposit to the FTO pair
        await usdt.connect(addr1).faucet();
        await usdt.connect(addr2).faucet();
        await usdt.connect(addr3).faucet(); 

        const depositAmount1 = ethers.utils.parseUnits("2000000", 18);
        const depositAmount2 = ethers.utils.parseUnits("3000000", 18);
        const depositAmount3 = ethers.utils.parseUnits("5000000", 18);


        // let initcode = await yexFTOFactory.getYexFTOPairInitCodeHash();
        // console.log("initcode====================", initcode);


        await usdt.connect(addr1).approve(yexFTOFacade.address, depositAmount1);
        await yexFTOFacade.connect(addr1).deposit(dRaisedToken, dLaunchedToken, depositAmount1, 0);

        await usdt.connect(addr2).approve(yexFTOFacade.address, depositAmount2);
        await yexFTOFacade.connect(addr2).deposit(dRaisedToken, dLaunchedToken, depositAmount2, 0);

        await usdt.connect(addr3).approve(yexFTOFacade.address, depositAmount3);
        await yexFTOFacade.connect(addr3).deposit(dRaisedToken, dLaunchedToken, depositAmount3, 0);

        console.log("USDT deposited successfully by addr1, addr2, and addr3");

        //3. Perform
        
        // Move time forward and mine a new block
        await network.provider.send("evm_increaseTime", [raisingCycle + 5]);
        await network.provider.send("evm_mine");


        const ftoPairAddr = await yexFTOFactory.getPair(dRaisedToken, dLaunchedToken);

        console.log("ftoPairAddr: ", ftoPairAddr);

        const YexFTOPair = await ethers.getContractFactory("YexFTOPair"); 
        const yexFTOPair = YexFTOPair.attach(ftoPairAddr);

        let univ2pairCodeHash = await uniswapV2Factory.pairCodeHash();
        console.log("univ2pairCodeHash: ", univ2pairCodeHash);

        await yexFTOPair.performUpkeep("0x");

        //4. check some

        const lpTokenAddr = await customHook.lpToken();
        const LPToken = await ethers.getContractFactory("UniswapV2Pair");
        const lpToken = LPToken.attach(lpTokenAddr);

        let ftoPairLPBalance = await lpToken.balanceOf(ftoPairAddr);
        expect(ftoPairLPBalance).to.equal(ethers.BigNumber.from("19999999999999999999999800"));

        let hookLPBalance = await lpToken.balanceOf(customHook.address);
        expect(hookLPBalance).to.equal(ethers.BigNumber.from("79999999999999999999999200"));


        //5. addr1 claims
        let claimableAmountAddr1 = await yexFTOFacade.connect(addr1).claimableLP(dRaisedToken, dLaunchedToken);
        expect(claimableAmountAddr1).to.equal(ethers.BigNumber.from("1999999999999999999999980"));

        await yexFTOFacade.connect(addr1).claimLP(dRaisedToken, dLaunchedToken, claimableAmountAddr1);
        claimableAmountAddr1 = await yexFTOFacade.connect(addr1).claimableLP(dRaisedToken, dLaunchedToken);
        expect(claimableAmountAddr1).to.equal(ethers.BigNumber.from("0"));

        //6. claimProjectLP
        let projectLPClaimableAmount = await yexFTOFacade.claimableLP(dRaisedToken, dLaunchedToken);
        expect(projectLPClaimableAmount).to.equal(ethers.BigNumber.from("9999999999999999999999900"));
        await customHook.claimProjectLP(projectLPClaimableAmount);

        //7. release vesting amount

        // Move time forward and mine a new block
        await network.provider.send("evm_increaseTime", [12]);
        await network.provider.send("evm_mine");

        await customHook.releaseVestedLP();

        hookLPBalance = await lpToken.balanceOf(customHook.address);
        expect(hookLPBalance).to.equal(ethers.BigNumber.from("0"));

        ftoPairLPBalance = await lpToken.balanceOf(ftoPairAddr);
        expect(ftoPairLPBalance).to.equal(ethers.BigNumber.from("87999999999999999999999120"));

        claimableAmountAddr1 = await yexFTOFacade.connect(addr1).claimableLP(dRaisedToken, dLaunchedToken);
        expect(claimableAmountAddr1).to.equal(ethers.BigNumber.from("7999999999999999999999920"));

        let claimableAmountAddr2 = await yexFTOFacade.connect(addr2).claimableLP(dRaisedToken, dLaunchedToken);
        expect(claimableAmountAddr2).to.equal(ethers.BigNumber.from("14999999999999999999999850"));
    });
})