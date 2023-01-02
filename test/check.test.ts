const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
import { expect } from "chai";
import { BigNumber, Contract } from "ethers";
import { ethers, upgrades } from "hardhat";

describe("Check", () => {
  let check: Contract;
  let lcheck: Contract;

  async function deployTokenFixture() {
    const [owner, addr1, addr2, addr3, addr4, addr5] = await ethers.getSigners();

    const LockedCheckToken = await ethers.getContractFactory("LockedCheckToken");
    lcheck = await upgrades.deployProxy(LockedCheckToken, ["Locked CHECK", "LCHECK"]);

    const totalSupply = 100_000_000_000 * (10 ** 6);
    const CheckToken = await ethers.getContractFactory("CheckToken");
    const check = await upgrades.deployProxy(CheckToken, ["Check Token", "CHECK", lcheck.address, addr5.address]);

    expect(await check.balanceOf(owner.address)).to.equal(BigNumber.from("100000000000000000"));

    return { check, lcheck, owner, totalSupply, addr1, addr2, addr3, addr4, addr5 };
  }

  describe("Check Contract", () => {
    it("user should be able to transfer CHECK token with fees", async () => {
        const { check, owner, addr1, addr2 } = await loadFixture(deployTokenFixture);
        const transferAmount = 1_000_000 * 10 ** 6;
      
        await check.connect(owner).transfer(addr1.address, transferAmount);
        expect(await check.balanceOf(addr1.address)).to.equal(transferAmount);
    });

    it("user should not be able to transfer without enough tokens on balance", async () => {
        const initialBalance = 50_000;
        const { addr1, addr2, check } = await loadFixture(deployTokenFixture);
  
        await expect(
          check.connect(addr2).transfer(addr1.address, initialBalance)
        ).to.be.revertedWith("ERC20: transfer exceeds balance");
    });

    it("user should be able to transfer with fees", async () => {
        const { totalSupply, owner, addr1, addr2, addr3, addr4, addr5, check } = await loadFixture(deployTokenFixture);
        
        const TAX_FEE = 5;
        const PROJECT_FEE = 3;
        
        const amount = 1_000_000 * 10 ** 6;
        
        const transferFee = amount * TAX_FEE / 100;
        const projectFee  = amount * PROJECT_FEE / 100;

        let totalUnits = 10**24;
        let currentRate = totalUnits / totalSupply;
        let reflectedAmount = amount * currentRate;
  
        await check.connect(owner).transfer(addr1.address, amount);
        expect(await check.balanceOf(addr1.address)).to.equal(amount);

        await check.connect(owner).transfer(addr3.address, amount);
        expect(await check.balanceOf(addr3.address)).to.equal(amount);
        await check.connect(addr3).transfer(addr4.address, amount);
        expect(await check.balanceOf(addr5.address)).to.equal(projectFee);

        expect(await check.balanceOf(addr3.address)).to.equal(0);

        const transferAmount = amount - transferFee - projectFee;
        const unitFee = transferFee * currentRate;

        totalUnits -= unitFee;
        const units = transferAmount * currentRate;                
        currentRate = totalUnits / totalSupply;

        expect(await check.balanceOf(addr4.address)).to.equal(Math.round(units / currentRate));
        expect(await check.balanceOf(addr1.address)).to.equal(Math.round(reflectedAmount / currentRate));
    });

    it("user should be able to transfer without fees when excluded", async () => {
      const { totalSupply, owner, addr3, addr4, check } = await loadFixture(deployTokenFixture);
      
      const amount = 5000 * 10 ** 6;
      expect(await check.balanceOf(addr3.address)).to.equal(0);
      expect(await check.balanceOf(addr4.address)).to.equal(0);
      await check.connect(owner).transfer(addr3.address, amount);
      expect(await check.balanceOf(addr3.address)).to.equal(amount);
      await check.connect(owner).excludeFromFee(addr3.address);
      await check.connect(addr3).transfer(addr4.address, amount);
      expect(await check.balanceOf(addr4.address)).to.equal(amount);
    });

    it("Power User should be able to transfer without fees", async () => {
      const { totalSupply, owner, addr1, addr2, addr3, addr4, check } = await loadFixture(deployTokenFixture);
      
      const amount = 100_000_000 * 10 ** 6;
      await check.connect(owner).transfer(addr1.address, amount);
      expect(await check.balanceOf(addr1.address)).to.equal(amount);
      await check.connect(addr1).transfer(addr4.address, amount / 2);
      expect(await check.balanceOf(addr4.address)).to.equal(amount / 2);

      await check.connect(addr1).transfer(addr3.address, amount / 2);
      expect(await check.balanceOf(addr3.address)).to.lt(amount / 2);
    });

    it("User should be able to send Power User without fees", async () => {
      const { totalSupply, owner, addr1, addr2, addr3, addr4, check } = await loadFixture(deployTokenFixture);
      
      const graceAmount = 100_000_000 * 10 ** 6;
      const amount = 10_000_000 * 10 ** 6;
      await check.connect(owner).transfer(addr1.address, graceAmount);
      await check.connect(owner).transfer(addr2.address, amount);

      expect(await check.balanceOf(addr1.address)).to.equal(graceAmount);
      expect(await check.balanceOf(addr2.address)).to.equal(amount);

      await check.connect(addr2).transfer(addr1.address, amount);
      expect(await check.balanceOf(addr1.address)).to.equal(amount + graceAmount);
    });

    it("User with disabled Power User should be charged by fee", async () => {
      const { totalSupply, owner, addr1, addr2, addr3, addr4, check } = await loadFixture(deployTokenFixture);
      await check.excludeFromPowerStatus(addr1.address);
      
      const graceAmount = 100_000_000 * 10 ** 6;
      const amount = 10_000_000 * 10 ** 6;
      await check.connect(owner).transfer(addr1.address, graceAmount);
      await check.connect(owner).transfer(addr2.address, amount);

      expect(await check.balanceOf(addr1.address)).to.equal(graceAmount);
      expect(await check.balanceOf(addr2.address)).to.equal(amount);

      await check.connect(addr1).transfer(addr2.address, amount);
      expect(await check.balanceOf(addr2.address)).to.lt(amount + graceAmount);
    });    

    it("user will not get fees if excluded", async () => {
      const { totalSupply, owner, addr1, addr2, addr3, addr4, check } = await loadFixture(deployTokenFixture);
        
      const TAX_FEE = 5;
      const PROJECT_FEE = 3;
      
      const amount = 500_000 * 10 ** 6;
      
      const transferFee = amount * TAX_FEE / 100;
      const projectFee  = amount * PROJECT_FEE / 100;

      let totalUnits = 10**24;
      let currentRate = totalUnits / totalSupply;

      await check.connect(owner).excludeFromReward(addr3.address);

      await check.connect(owner).transfer(addr1.address, amount);
      expect(await check.balanceOf(addr1.address)).to.equal(amount);

      await check.connect(owner).transfer(addr2.address, amount);
      expect(await check.balanceOf(addr2.address)).to.equal(amount);

      await check.connect(owner).transfer(addr3.address, amount);
      await check.connect(addr1).transfer(addr4.address, amount);
      expect(await check.balanceOf(addr3.address)).to.equal(amount);

      const transferAmount = amount - transferFee - projectFee;
      const unitFee = transferFee * currentRate;

      totalUnits -= unitFee;
      let units = transferAmount * currentRate; 
      currentRate = totalUnits / totalSupply;
      expect(await check.balanceOf(addr4.address)).to.equal(Math.round(units / currentRate));
    });

    it("user should not be able to transfer LCHECK token", async () => {
      const { owner, addr1, addr2, lcheck } = await loadFixture(deployTokenFixture);
      const amount = 1000 * 10 ** 6;
      await lcheck.connect(owner).mint(addr1.address, amount);
      expect(await lcheck.balanceOf(addr1.address)).to.equal(amount);

      await expect(
        lcheck.connect(addr1).transfer(addr2.address, amount)
      ).to.be.revertedWith("TransferDenied()");

      await lcheck.connect(owner).burn(addr1.address, amount);
      expect(await lcheck.balanceOf(addr1.address)).to.equal(0);
    });
  });
});
