const Utils = artifacts.require("./lib/Utils.sol");
const Constants = artifacts.require("./lib/Constants.sol");
const Enums = artifacts.require("../lib/Enums.sol");
const Structs = artifacts.require("../lib/Structs.sol");

const Sidemesh = artifacts.require("./sidemesh/Sidemesh.sol");
const Verifier = artifacts.require("./resource/Verifier.sol");
const Register = artifacts.require("./resource/Register.sol");
const LockManager = artifacts.require("./lock/LockManager.sol");
const GlobalTransactionManager = artifacts.require(
	"./transaction/GlobalTransactionManager.sol"
);

module.exports = async function (deployer) {
	await deployer.deploy(Utils, { overwrite: false });
	await deployer.deploy(Constants, { overwrite: false });
	await deployer.deploy(Enums, { overwrite: false });
	await deployer.deploy(Structs, { overwrite: false });

	await deployer.link(Utils, [Sidemesh, Verifier, Register, LockManager]);
	await deployer.link(Constants, [
		Sidemesh,
		Verifier,
		Register,
		LockManager,
	]);
	await deployer.link(Enums, LockManager);
	await deployer.link(Structs, [Verifier, Register, LockManager]);

	const sidemesh = await deployer.deploy(Sidemesh);
	await deployer.deploy(LockManager, sidemesh.address);
	await deployer.deploy(Verifier);
	await deployer.deploy(Register);
};
