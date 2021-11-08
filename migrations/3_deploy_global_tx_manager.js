const Utils = artifacts.require("./lib/Utils.sol");
const Constants = artifacts.require("./lib/Constants.sol");
const Enums = artifacts.require("../lib/Enums.sol");
const Structs = artifacts.require("../lib/Structs.sol");

const Sidemesh = artifacts.require("Sidemesh");
const Verifier = artifacts.require("Verifier");
const Register = artifacts.require("Register");
const LockManager = artifacts.require("./lock/LockManager.sol");
const GlobalTransactionManager = artifacts.require(
	"./transaction/GlobalTransactionManager.sol"
);

module.exports = async function (deployer) {
	await deployer.deploy(Utils, { overwrite: false });
	await deployer.deploy(Constants, { overwrite: false });
	await deployer.deploy(Enums, { overwrite: false });
	await deployer.deploy(Structs, { overwrite: false });

	await deployer.link(Utils, GlobalTransactionManager);
	await deployer.link(Constants, GlobalTransactionManager);
	await deployer.link(Enums, GlobalTransactionManager);
	await deployer.link(Structs, GlobalTransactionManager);

	const sidemesh = await Sidemesh.deployed();
	const verifier = await Verifier.deployed();
	const register = await Register.deployed();
	const lockManager = await LockManager.deployed();
	await deployer.deploy(
		GlobalTransactionManager,
		sidemesh.address,
		register.address,
		verifier.address,
		lockManager.address
	);
};
