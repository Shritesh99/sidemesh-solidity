const Lib = artifacts.require("./lib/Lib.sol");
const Verifier = artifacts.require("./resource/Verifier.sol");
const Register = artifacts.require("./resource/Register.sol");
const LockManager = artifacts.require("./lock/LockManager.sol");
const GlobalTransactionManager = artifacts.require(
	"./transaction/GlobalTransactionManager.sol"
);

module.exports = async function (deployer) {
	await deployer.deploy(Lib);
	await deployer.link(Lib, Verifier);
	await deployer.link(Lib, Register);
	await deployer.link(Lib, LockManager);
	await deployer.link(Lib, GlobalTransactionManager);

	const verifier = await deployer.deploy(Verifier);
	const register = await deployer.deploy(Register);
	const lockManager = await deployer.deploy(LockManager);
	await deployer.deploy(
		GlobalTransactionManager,
		register.address,
		verifier.address,
		lockManager.address
	);
};
