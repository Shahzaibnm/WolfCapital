/**
               _  __          
__      _____ | |/ _|         
\ \ /\ / / _ \| | |_          
 \ V  V / (_) | |  _|         
  \_/\_/ \___/|_|_|           
                              
                 _ _        _ 
  ___ __ _ _ __ (_) |_ __ _| |
 / __/ _` | '_ \| | __/ _` | |
| (_| (_| | |_) | | || (_| | |
 \___\__,_| .__/|_|\__\__,_|_|
          |_|                 
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IWolf {
    function calculateReward(
        address _user,
        uint256 _index
    ) external view returns (uint256 _reward);

    function getUserInfo(
        address _user
    )
        external
        view
        returns (
            bool _isExists,
            uint256 _stakeCount,
            address _referrer,
            uint256 _referrals,
            uint256 _referralRewards,
            uint256 _teamId,
            uint256 _currentStaked,
            uint256 _totalStaked,
            uint256 _totalWithdrawan
        );

    function getUserTokenStakeInfo(
        address _user,
        uint256 _index
    )
        external
        view
        returns (
            uint256 _amount,
            uint256 _checkpoint,
            uint256 _claimedReward,
            uint256 _startTime,
            bool _isActive
        );

    function getUserLotteryClaimedStatus(
        address _user,
        uint256 _week
    ) external view returns (bool _status);

    function getTeamInfo(
        uint256 _teamId
    )
        external
        view
        returns (
            address _Lead,
            string memory _teamName,
            uint256 _teamCount,
            uint256 _teamAmount,
            uint256 _currentPercent
        );

    function getAllTeamMembers(
        uint256 _teamId,
        uint256 _index
    ) external view returns (address _teamMember);

    function getTeamLotteryAmount(
        uint256 _teamId,
        uint256 _week
    ) external view returns (uint256 _amount);

    function getTeamWeeklyDepositAmount(
        uint256 _teamId,
        uint256 _week
    ) external view returns (uint256 _amount);

    function getWinnersHistory(
        uint256 _week
    ) external view returns (uint256 _team);
}

contract WolfCapital is Initializable, OwnableUpgradeable {
    using SafeMath for uint256;
    IERC20MetadataUpgradeable public usdc;
    IWolf public wolfV1;
    address public ownerWallet;
    address public marketingWallet;
    address public developmentWallet1;
    address public developmentWallet2;
    address public multiSigWallet;

    uint256 public totalStaked;
    uint256 public totalWithdrawan;
    uint256 public totalRefRewards;
    uint256 public uniqueStakers;
    uint256 public topDepositThisWeek;
    uint256 public topTeamThisWeek;
    uint256 public lotteryPool;
    uint256 public uniqueTeamId;
    uint256 public currentWeek;
    uint256 public launchTime;
    uint256 public haltAccStartTime;
    uint256 public haltAccEndTime;
    bool public haltDeposits;
    bool public haltWithdraws;
    bool public haltAccumulation;
    bool public launched;

    uint256 public basePercent;
    uint256 public teamPercentMultiplier;
    uint256 public ownerFeePercent;
    uint256 public marketingFeePercent;
    uint256 public dev1FeePercent;
    uint256 public dev2FeePercent;
    uint256 public lotteryFeePercent;
    uint256 public lotteryPercent;
    uint256 public referrerPercent;
    uint256 public referralPercent;
    uint256 public percentDivider;
    uint256 public minDeposit;
    uint256 public maxDeposit;
    uint256 public timeStep;
    uint256 public claimDuration;
    uint256 public accumulationDuration;
    uint256 public lockDuration;

    uint256[10] public requiredTeamUsers;
    uint256[10] public requiredTeamAmount;

    struct StakeData {
        uint256 amount;
        uint256 checkpoint;
        uint256 claimedReward;
        uint256 startTime;
        bool isActive;
    }

    struct User {
        bool isExists;
        address referrer;
        uint256 referrals;
        uint256 referralRewards;
        uint256 teamId;
        uint256 stakeCount;
        uint256 currentStaked;
        uint256 totalStaked;
        uint256 totalWithdrawan;
    }

    struct TeamData {
        address Lead;
        string teamName;
        uint256 teamCount;
        uint256 teamAmount;
        uint256 currentPercent;
        address[] teamMembers;
        mapping(uint256 => uint256) lotteryAmount;
        mapping(uint256 => uint256) weeklyDeposits;
    }

    mapping(address => User) internal users;
    mapping(uint256 => TeamData) internal teams;
    mapping(address => mapping(uint256 => StakeData)) internal userStakes;
    mapping(address => mapping(uint256 => bool)) internal isLotteryClaimed;
    mapping(uint256 => uint256) internal winnersHistory;
    mapping(address => bool) internal isUserMigrated;
    mapping(uint256 => bool) internal isTeamMigrated;

    event STAKE(address Staker, uint256 amount);
    event CLAIM(address Staker, uint256 amount);
    event WITHDRAW(address Staker, uint256 amount);
    event LOTTERY(
        uint256 topTeamThisWeek,
        uint256 lotteryAmount,
        uint256 lastWeekTopDeposit
    );

    function initialize() public initializer {
        wolfV1 = IWolf(0x4Bba559128f2630459655AD548A5b6e5F31d97f4);
        usdc = IERC20MetadataUpgradeable(
            0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d
        );
        owner = 0x5886B6b942f8DaB2488961f603a4be8C3015A1A9;
        dev = 0x7f35be372873e06c15DD7f9494A426ACab99C6De;
        ownerWallet = owner;
        marketingWallet = 0x57741A3F319D526F9DdBa1D181207C8bD06c2914;
        developmentWallet1 = dev;
        developmentWallet2 = 0x7DB1A2f972652020e8664005B6119F21A64C39B8;
        multiSigWallet = 0x05c09F12e03a56FbC03EdB8acB2ef7933E1Ff45C;
        basePercent = 1_00;
        teamPercentMultiplier = 10;
        ownerFeePercent = 3_00;
        marketingFeePercent = 4_00;
        dev1FeePercent = 1_00;
        dev2FeePercent = 1_00;
        lotteryFeePercent = 1_00;
        lotteryPercent = 30_00;
        referrerPercent = 1_50;
        referralPercent = 1_50;
        percentDivider = 100_00;
        minDeposit = 50e18;
        maxDeposit = 100_000e18;
        timeStep = 1 minutes;
        claimDuration = 7 minutes;
        accumulationDuration = 10 minutes;
        lockDuration = 60 minutes;
    }

    function migratemultipleUsers(address[] memory _users) external onlyOwner {
        for (uint256 i; i < _users.length; i++) {
            migrateUserData(_users[i]);
            migrateUserDataRemaining(_users[i]);
            migrateUserStakeData(_users[i]);
            isUserMigrated[_users[i]] = true;
        }
    }

    function migrateUserData(address _user) internal {
        (
            users[_user].isExists,
            users[_user].stakeCount,
            users[_user].referrer,
            users[_user].referrals,
            users[_user].referralRewards,
            ,
            ,
            ,

        ) = wolfV1.getUserInfo(_user);
    }

    function migrateUserDataRemaining(address _user) internal {
        (
            ,
            ,
            ,
            ,
            ,
            users[_user].teamId,
            users[_user].currentStaked,
            users[_user].totalStaked,
            users[_user].totalWithdrawan
        ) = wolfV1.getUserInfo(_user);
    }

    function migrateUserStakeData(address _user) internal {
        for (uint i; i < users[_user].stakeCount; i++) {
            (
                userStakes[_user][i].amount,
                userStakes[_user][i].checkpoint,
                userStakes[_user][i].claimedReward,
                ,

            ) = wolfV1.getUserTokenStakeInfo(_user, i);
            migrateUserStakeRemainingData(_user, i);
        }
    }

    function migrateUserStakeRemainingData(
        address _user,
        uint256 _count
    ) internal {
        (
            ,
            ,
            ,
            userStakes[_user][_count].startTime,
            userStakes[_user][_count].isActive
        ) = wolfV1.getUserTokenStakeInfo(_user, _count);
    }

    function migrateTeamData(uint256[] memory _teamIds) external onlyOwner {
        for (uint i; i < _teamIds.length; i++) {
            migrateRemainingTeamData(_teamIds[i]);
            isTeamMigrated[_teamIds[i]] = true;
        }
    }

    function migrateRemainingTeamData(uint256 _teamId) internal {
            (
                teams[_teamId].Lead,
                teams[_teamId].teamName,
                teams[_teamId].teamCount,
                teams[_teamId].teamAmount,
                teams[_teamId].currentPercent
            ) = wolfV1.getTeamInfo(_teamId);
            isTeamMigrated[_teamId] = true;
    }

    function updateWeekly() public {
        if (currentWeek != calculateWeek()) {
            checkForLotteryWinner();
            currentWeek = calculateWeek();
            topDepositThisWeek = 0;
        }
    }

    function stake(address _referrer, uint256 _amount) public {
        require(launched, "Wait for launch");
        require(!haltDeposits, "Admin halt deposits");
        updateWeekly();
        User storage user = users[msg.sender];
        require(_amount >= minDeposit, "Amount less than min amount");
        require(
            user.currentStaked + _amount <= maxDeposit,
            "Amount more than max amount"
        );
        if (!user.isExists) {
            user.isExists = true;
            uniqueStakers++;
        }

        totalStaked += _amount;
        usdc.transferFrom(msg.sender, address(this), _amount);
        takeFee(_amount);
        _amount = (_amount * 90) / 100;

        StakeData storage userStake = userStakes[msg.sender][user.stakeCount];
        userStake.amount = _amount;
        userStake.startTime = block.timestamp;
        userStake.checkpoint = block.timestamp;
        userStake.isActive = true;
        user.stakeCount++;
        user.totalStaked += _amount;
        user.currentStaked += _amount;

        if (_referrer == msg.sender) {
            _referrer = address(0);
        }

        if (user.referrer == address(0)) {
            if (user.teamId == 0) {
                setReferrer(msg.sender, _referrer);
            }
        }

        if (user.referrer != address(0)) {
            distributeRefReward(msg.sender, _amount);
        }

        updateTeam(msg.sender, _amount);

        emit STAKE(msg.sender, _amount);
    }

    function setReferrer(address _user, address _referrer) private {
        User storage user = users[_user];

        if (_referrer == address(0)) {
            createTeam(_user);
        } else if (_referrer != _user) {
            user.referrer = _referrer;
        }

        if (user.referrer != address(0)) {
            users[user.referrer].referrals++;
        }
    }

    function distributeRefReward(address _user, uint256 _amount) private {
        User storage user = users[_user];

        uint256 userRewards = _amount.mul(referralPercent).div(percentDivider);
        uint256 refRewards = _amount.mul(referrerPercent).div(percentDivider);

        usdc.transfer(_user, userRewards);
        usdc.transfer(user.referrer, refRewards);

        user.referralRewards += userRewards;
        users[user.referrer].referralRewards += refRewards;
        totalRefRewards += userRewards;
        totalRefRewards += refRewards;
    }

    function createTeam(address _user) private {
        User storage user = users[_user];
        user.teamId = ++uniqueTeamId;
        TeamData storage newTeam = teams[user.teamId];
        newTeam.Lead = _user;
        newTeam.teamName = Strings.toString(user.teamId);
        newTeam.teamMembers.push(_user);
        newTeam.teamCount++;
    }

    function updateTeam(address _user, uint256 _amount) private {
        User storage user = users[_user];

        if (user.teamId == 0) {
            user.teamId = users[user.referrer].teamId;
            teams[user.teamId].teamCount++;
            teams[user.teamId].teamMembers.push(_user);
        }

        TeamData storage team = teams[user.teamId];
        team.teamAmount += _amount;
        team.weeklyDeposits[currentWeek] += _amount;
        if (team.weeklyDeposits[currentWeek] > topDepositThisWeek) {
            topDepositThisWeek = team.weeklyDeposits[currentWeek];
            topTeamThisWeek = user.teamId;
        }

        uint256 amountIndex = team.teamAmount /
            (requiredTeamAmount[0] * 10 ** usdc.decimals());
        uint256 countIndex = team.teamCount / requiredTeamUsers[0];
        if (amountIndex == countIndex) {
            team.currentPercent = amountIndex * teamPercentMultiplier;
        } else if (amountIndex < countIndex) {
            team.currentPercent = amountIndex * teamPercentMultiplier;
        } else {
            team.currentPercent = countIndex * teamPercentMultiplier;
        }
        if (team.currentPercent > 100) {
            team.currentPercent = 100;
        }
    }

    function takeFee(uint256 _amount) private {
        usdc.transfer(
            ownerWallet,
            (_amount * ownerFeePercent) / percentDivider
        );
        usdc.transfer(
            marketingWallet,
            (_amount * marketingFeePercent) / percentDivider
        );
        usdc.transfer(
            developmentWallet1,
            (_amount * dev1FeePercent) / percentDivider
        );
        usdc.transfer(
            developmentWallet2,
            (_amount * dev2FeePercent) / percentDivider
        );
        lotteryPool += (_amount * lotteryFeePercent) / percentDivider;
    }

    function claim(uint256 _index) public {
        require(launched, "Wait for launch");
        require(!haltWithdraws, "Admin halt withdrawls");
        updateWeekly();
        User storage user = users[msg.sender];
        StakeData storage userStake = userStakes[msg.sender][_index];
        require(_index < user.stakeCount, "Invalid index");
        require(userStake.isActive, "Already withdrawn");
        require(
            block.timestamp >= userStake.checkpoint + claimDuration,
            "Wait for claim time"
        );
        uint256 rewardAmount;
        rewardAmount = calculateReward(msg.sender, _index);
        require(rewardAmount > 0, "Can't claim 0");
        usdc.transfer(msg.sender, rewardAmount);
        userStake.checkpoint = block.timestamp;
        userStake.claimedReward += rewardAmount;
        user.totalWithdrawan += rewardAmount;
        totalWithdrawan += rewardAmount;

        emit CLAIM(msg.sender, rewardAmount);
    }

    function claimAll() public {
        require(launched, "Wait for launch");
        require(!haltWithdraws, "Admin halt withdrawls");
        updateWeekly();

        User storage user = users[msg.sender];
        uint256 claimableReward;
        for (uint i; i < user.stakeCount; i++) {
            StakeData storage userStake = userStakes[msg.sender][i];
            if (
                userStake.isActive &&
                block.timestamp >= userStake.checkpoint + claimDuration
            ) {
                uint256 rewardAmount;
                rewardAmount = calculateReward(msg.sender, i);
                userStake.checkpoint = block.timestamp;
                userStake.claimedReward += rewardAmount;
                claimableReward += rewardAmount;
            }
        }
        require(claimableReward > 0, "Can't claim 0");
        usdc.transfer(msg.sender, claimableReward);

        user.totalWithdrawan += claimableReward;
        totalWithdrawan += claimableReward;

        emit CLAIM(msg.sender, claimableReward);
    }

    function withdraw(uint256 _index) public {
        require(launched, "Wait for launch");
        require(!haltWithdraws, "Admin halt withdrawls");
        updateWeekly();

        User storage user = users[msg.sender];
        StakeData storage userStake = userStakes[msg.sender][_index];
        require(_index < user.stakeCount, "Invalid index");
        require(userStake.isActive, "Already withdrawn");
        require(
            block.timestamp >= userStake.startTime + lockDuration,
            "Wait for end time"
        );

        usdc.transfer(msg.sender, userStake.amount);
        userStake.isActive = false;
        userStake.checkpoint = block.timestamp;
        user.currentStaked -= userStake.amount;
        user.totalWithdrawan += userStake.amount;
        totalWithdrawan += userStake.amount;

        emit WITHDRAW(msg.sender, userStake.amount);
    }

    function checkForLotteryWinner() private {
        uint256 lotteryAmount = (lotteryPool * lotteryPercent) / percentDivider;
        teams[topTeamThisWeek].lotteryAmount[currentWeek] = lotteryAmount;
        winnersHistory[currentWeek] = topTeamThisWeek;
        lotteryPool -= lotteryAmount;

        emit LOTTERY(topTeamThisWeek, lotteryAmount, topDepositThisWeek);
    }

    function claimLottery() public {
        User storage user = users[msg.sender];
        TeamData storage team = teams[user.teamId];

        require(
            !isLotteryClaimed[msg.sender][currentWeek - 1],
            "Already Claimed"
        );
        require(team.lotteryAmount[currentWeek - 1] > 0, "No reward to Claim");

        uint256 userShare = (user.currentStaked * percentDivider) /
            team.teamAmount;
        usdc.transfer(
            msg.sender,
            (team.lotteryAmount[currentWeek - 1] * userShare) / percentDivider
        );
        isLotteryClaimed[msg.sender][currentWeek - 1] = true;
    }

    /**
        Getter functions for Public
     */

    function calculateWeek() public view returns (uint256) {
        return (block.timestamp - launchTime) / (7 * timeStep);
    }

    function calculateReward(
        address _user,
        uint256 _index
    ) public view returns (uint256 _reward) {
        if (haltAccumulation) return 0;
        StakeData storage userStake = userStakes[_user][_index];
        TeamData storage team = teams[users[_user].teamId];
        uint256 rewardDuration = block.timestamp.sub(userStake.checkpoint);
        if (userStake.checkpoint < haltAccStartTime) {
            rewardDuration =
                rewardDuration -
                (haltAccEndTime - haltAccStartTime);
        }
        if (rewardDuration > accumulationDuration) {
            rewardDuration = accumulationDuration;
        }
        _reward = userStake
            .amount
            .mul(rewardDuration)
            .mul(basePercent + team.currentPercent)
            .div(percentDivider.mul(timeStep));
    }

    function getUserInfo(
        address _user
    )
        public
        view
        returns (
            bool _isExists,
            uint256 _stakeCount,
            address _referrer,
            uint256 _referrals,
            uint256 _referralRewards,
            uint256 _teamId,
            uint256 _currentStaked,
            uint256 _totalStaked,
            uint256 _totalWithdrawan
        )
    {
        User storage user = users[_user];
        _isExists = user.isExists;
        _stakeCount = user.stakeCount;
        _referrer = user.referrer;
        _referrals = user.referrals;
        _referralRewards = user.referralRewards;
        _teamId = user.teamId;
        _currentStaked = user.currentStaked;
        _totalStaked = user.totalStaked;
        _totalWithdrawan = user.totalWithdrawan;
    }

    function getUserTokenStakeInfo(
        address _user,
        uint256 _index
    )
        public
        view
        returns (
            uint256 _amount,
            uint256 _checkpoint,
            uint256 _claimedReward,
            uint256 _startTime,
            bool _isActive
        )
    {
        StakeData storage userStake = userStakes[_user][_index];
        _amount = userStake.amount;
        _checkpoint = userStake.checkpoint;
        _claimedReward = userStake.claimedReward;
        _startTime = userStake.startTime;
        _isActive = userStake.isActive;
    }

    function getUserLotteryClaimedStatus(
        address _user,
        uint256 _week
    ) public view returns (bool _status) {
        _status = isLotteryClaimed[_user][_week];
    }

    function getTeamInfo(
        uint256 _teamId
    )
        public
        view
        returns (
            address _Lead,
            string memory _teamName,
            uint256 _teamCount,
            uint256 _teamAmount,
            uint256 _currentPercent
        )
    {
        TeamData storage team = teams[_teamId];
        _Lead = team.Lead;
        _teamName = team.teamName;
        _teamCount = team.teamCount;
        _teamAmount = team.teamAmount;
        _currentPercent = team.currentPercent;
    }

    function getAllTeamMembers(
        uint256 _teamId,
        uint256 _index
    ) public view returns (address _teamMember) {
        _teamMember = teams[_teamId].teamMembers[_index];
    }

    function getTeamLotteryAmount(
        uint256 _teamId,
        uint256 _week
    ) public view returns (uint256 _amount) {
        _amount = teams[_teamId].lotteryAmount[_week];
    }

    function getTeamWeeklyDepositAmount(
        uint256 _teamId,
        uint256 _week
    ) public view returns (uint256 _amount) {
        _amount = teams[_teamId].weeklyDeposits[_week];
    }

    function getWinnersHistory(
        uint256 _week
    ) public view returns (uint256 _team) {
        _team = winnersHistory[_week];
    }

    function getUserMigrationStatus(address _user) public view returns (bool) {
        return isUserMigrated[_user];
    }

    function getTeamMigrationStatus(
        uint256 _teamId
    ) public view returns (bool) {
        return isTeamMigrated[_teamId];
    }

    function getContractBalance() public view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    /*
        Setter functions For Owner
    */

    function migrateAllStateValues(
        uint256[10] memory _values
    ) external onlyOwner {
        totalStaked = _values[0];
        totalWithdrawan = _values[1];
        totalRefRewards = _values[2];
        uniqueStakers = _values[3];
        topDepositThisWeek = _values[4];
        topTeamThisWeek = _values[5];
        lotteryPool = _values[6];
        uniqueTeamId = _values[7];
        currentWeek = _values[8];
        launchTime = _values[9];
        launched = true;
    }

    function launch() external onlyOwner {
        require(!launched, "Already launched");
        launched = true;
        launchTime = block.timestamp;
    }

    function setHaltDeposits(bool _state) external onlyOwner {
        haltDeposits = _state;
    }

    function setHaltWithdraws(bool _state) external onlyOwner {
        haltWithdraws = _state;
    }

    function setHaltAccumulation(bool _state) external onlyOwner {
        haltAccumulation = _state;
        if (_state) {
            haltAccStartTime = block.timestamp;
        } else {
            haltAccEndTime = block.timestamp;
        }
    }

    function migrateFunds(address _token, uint256 _amount) external {
        require(msg.sender == multiSigWallet, "Not a multisig");
        IERC20MetadataUpgradeable(_token).transfer(owner, _amount);
    }

    function SetTeamName(string memory _name) external {
        TeamData storage team = teams[users[msg.sender].teamId];
        require(msg.sender == team.Lead, "Not a leader");
        team.teamName = _name;
    }

    function SetDepositLimits(uint256 _min, uint256 _max) external onlyOwner {
        minDeposit = _min;
        maxDeposit = _max;
    }

    function setFeeWallets(
        address _ownerWallet,
        address _marketingWallet,
        address _developmentWallet1,
        address _developmentWallet2
    ) external onlyOwner {
        ownerWallet = _ownerWallet;
        marketingWallet = _marketingWallet;
        developmentWallet1 = _developmentWallet1;
        developmentWallet2 = _developmentWallet2;
    }

    function setMultiSigWallet(address _newWallet) external {
        require(msg.sender == multiSigWallet, "Not a multisig");
        multiSigWallet = _newWallet;
    }

    function setContracts(
        address _newToken,
        address _oldWolf
    ) external onlyOwner {
        usdc = IERC20MetadataUpgradeable(_newToken);
        wolfV1 = IWolf(_oldWolf);
    }

    function setBasePercent(
        uint256 _basePercent,
        uint256 _teamPercent
    ) external onlyOwner {
        basePercent = _basePercent;
        teamPercentMultiplier = _teamPercent;
    }
}

library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";

    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}