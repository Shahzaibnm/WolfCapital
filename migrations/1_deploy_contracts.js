// const { deployProxy } = require("@openzeppelin/truffle-upgrades");
// const WolfCapital = artifacts.require("WolfCapital");

// module.exports = async function (deployer) {
//   const instance = await deployProxy(
//     WolfCapital,
//     [
//      ],
//     { deployer }
//   );
//   console.log("Deployed", instance.address);
// };

const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const Refund = artifacts.require("WolfCapital7");

const RefundV2 = artifacts.require('WolfCapital8');

module.exports = async function (deployer) {
    const existing = await Refund.deployed();
    const instance = await upgradeProxy(existing.address, RefundV2, ["0x5FAc8717fdFBbf36f7c7217A424C7c82661297A6", 10], { deployer });
    console.log("Upgraded", instance.address);
  };