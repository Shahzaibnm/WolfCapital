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
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract WolfCapital8 is Initializable, OwnableUpgradeable {
    using SafeMath for uint256;
    IERC20MetadataUpgradeable public usdc;
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

    function initialize() public initializer {}

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

    uint256 public currentStaked;
    address public developmentWallet3;
    uint256 public dev3FeePercent;
    mapping(address => mapping(uint256 => uint256)) weeklyDeposits;
    address public dev2;
    uint256 public accumulationDurationVip;
    address public alpha;
    address public beta;
    address public omega;

    modifier onlyDev() {
        require(dev2 == _msgSender(), "caller is not the dev");
        _;
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

        startStake(msg.sender, _amount);
        weeklyDeposits[msg.sender][currentWeek] += _amount;

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
    }

    function startStake(address _user, uint256 _amount) private {
        User storage user = users[msg.sender];
        StakeData storage userStake = userStakes[msg.sender][user.stakeCount];
        userStake.amount = _amount;
        userStake.startTime = block.timestamp;
        userStake.checkpoint = block.timestamp;
        userStake.isActive = true;
        user.stakeCount++;
        user.totalStaked += _amount;
        user.currentStaked += _amount;
        currentStaked += _amount;

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
        if (amountIndex > requiredTeamAmount.length) {
            amountIndex = requiredTeamAmount.length;
        }
        uint256 countIndex = team.teamCount / requiredTeamUsers[0];
        if (countIndex > requiredTeamUsers.length) {
            countIndex = requiredTeamUsers.length;
        }
        if (amountIndex == countIndex) {
            team.currentPercent = amountIndex * teamPercentMultiplier;
        } else if (amountIndex < countIndex) {
            team.currentPercent = amountIndex * teamPercentMultiplier;
        } else {
            team.currentPercent = countIndex * teamPercentMultiplier;
        }
        if (team.currentPercent > 50) {
            team.currentPercent = 50;
        }
    }

    function takeFee(uint256 _amount) private {
        if (ownerWallet != address(0)) {
            usdc.transfer(
                ownerWallet,
                (_amount * ownerFeePercent) / percentDivider
            );
        }
        if (marketingWallet != address(0)) {
            usdc.transfer(
                marketingWallet,
                (_amount * marketingFeePercent) / percentDivider
            );
        }
        if (developmentWallet1 != address(0)) {
            usdc.transfer(
                developmentWallet1,
                (_amount * dev1FeePercent) / percentDivider
            );
        }
        if (developmentWallet2 != address(0)) {
            usdc.transfer(
                developmentWallet2,
                (_amount * dev2FeePercent) / percentDivider
            );
        }
        if (developmentWallet3 != address(0)) {
            usdc.transfer(
                developmentWallet3,
                (_amount * dev3FeePercent) / percentDivider
            );
        }
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
        endStake(msg.sender, _index);
    }

    function endStake(address _user, uint256 _index) private {
        User storage user = users[_user];
        StakeData storage userStake = userStakes[_user][_index];
        userStake.isActive = false;
        userStake.checkpoint = block.timestamp;
        user.currentStaked -= userStake.amount;
        currentStaked -= userStake.amount;
        user.totalWithdrawan += userStake.amount;
        totalWithdrawan += userStake.amount;

        emit WITHDRAW(_user, userStake.amount);
    }

    function mergeAll() public {
        User storage user = users[msg.sender];
        uint256 claimableReward;
        uint256 withdrawableAmount;
        for (uint256 i; i < user.stakeCount; i++) {
            StakeData storage userStake = userStakes[msg.sender][i];
            if (userStake.isActive && block.timestamp >= userStake.startTime + lockDuration) {
                claimableReward += calculateReward(msg.sender, i);
                userStake.claimedReward += rewardAmount;
                withdrawableAmount += userStake.amount;
                endStake(msg.sender, i);
            }
        }
        startStake(msg.sender, claimableReward + withdrawableAmount);
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
        require(
            weeklyDeposits[msg.sender][currentWeek - 1] > 0,
            "No reward to Claim"
        );

        uint256 userShare = (weeklyDeposits[msg.sender][currentWeek - 1] *
            percentDivider) / team.weeklyDeposits[currentWeek - 1];
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
        if (isNftUser(_user)) {
            if (rewardDuration > accumulationDurationVip) {
                rewardDuration = accumulationDurationVip;
            }
        } else {
            if (rewardDuration > accumulationDuration) {
                rewardDuration = accumulationDuration;
            }
        }
        _reward = userStake
            .amount
            .mul(rewardDuration)
            .mul(basePercent + team.currentPercent)
            .div(percentDivider.mul(timeStep));
    }

    function isNftUser(address _user) public returns (bool) {
        if (
            IERC721Upgradeable(alpha).balanceOf(_user) > 0 ||
            IERC721Upgradeable(beta).balanceOf(_user) > 0 ||
            IERC721Upgradeable(omega).balanceOf(_user) > 0
        ) {
            return true;
        } else return false;
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

    function getUserWeeklyDepositAmount(
        address _user,
        uint256 _week
    ) public view returns (uint256 _amount) {
        _amount = weeklyDeposits[_user][_week];
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
        Setter functions For sOwner
    */

    function setNewDev(address newDev) public onlyDev {
        dev2 = newDev;
    }

    function launch() external onlyOwner onlyDev {
        require(!launched, "Already launched");
        launched = true;
        launchTime = block.timestamp;
    }

    function setHaltDeposits(bool _state) external onlyOwner onlyDev {
        haltDeposits = _state;
    }

    function setHaltWithdraws(bool _state) external onlyOwner onlyDev {
        haltWithdraws = _state;
    }

    function setHaltAccumulation(bool _state) external onlyOwner onlyDev {
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

    function SetDepositLimits(
        uint256 _min,
        uint256 _max
    ) external onlyOwner onlyDev {
        minDeposit = _min;
        maxDeposit = _max;
    }

    function setFeeWallets(
        address _ownerWallet,
        address _marketingWallet,
        address _developmentWallet1,
        address _developmentWallet2,
        address _developmentWallet3
    ) external onlyOwner onlyDev {
        ownerWallet = _ownerWallet;
        marketingWallet = _marketingWallet;
        developmentWallet1 = _developmentWallet1;
        developmentWallet2 = _developmentWallet2;
        developmentWallet3 = _developmentWallet3;
    }

    function setFees(
        address _ownerFeePercent,
        address _marketingFeePercent,
        address _dev1FeePercent,
        address _dev2FeePercent,
        address _dev3FeePercent
    ) external onlyOwner onlyDev {
        ownerFeePercent = _ownerFeePercent;
        marketingFeePercent = _marketingFeePercent;
        dev1FeePercent = _dev1FeePercent;
        dev2FeePercent = _dev2FeePercent;
        dev3FeePercent = _dev3FeePercent;
    }

    function setMultiSigWallet(address _newWallet) external {
        require(msg.sender == multiSigWallet, "Not a multisig");
        multiSigWallet = _newWallet;
    }

    function setContracts(
        address _usdc,
        address _alpha,
        address _beta,
        address _omega
    ) external onlyOwner onlyDev {
        usdc = IERC20MetadataUpgradeable(_usdc);
        alpha = _alpha;
        beta = _beta;
        omega = _omega;
    }

    function setBasePercent(
        uint256 _basePercent,
        uint256 _teamPercent
    ) external onlyOwner onlyDev {
        basePercent = _basePercent;
        teamPercentMultiplier = _teamPercent;
    }

    function setDurations(
        uint256 _1,
        uint256 _2,
        uint256 _3,
        uint256 _4,
        uint256 _5
    ) external onlyOwner onlyDev {
        timeStep = _1;
        claimDuration = _2;
        accumulationDuration = _3;
        accumulationDurationVip = _4;
        lockDuration = _5;
    }

    function setRequiredTeamAmount(
        uint256[10] memory _values
    ) external onlyOwner onlyDev {
        requiredTeamAmount[0] = _values[0];
        requiredTeamAmount[1] = _values[1];
        requiredTeamAmount[2] = _values[2];
        requiredTeamAmount[3] = _values[3];
        requiredTeamAmount[4] = _values[4];
        requiredTeamAmount[5] = _values[5];
        requiredTeamAmount[6] = _values[6];
        requiredTeamAmount[7] = _values[7];
        requiredTeamAmount[8] = _values[8];
        requiredTeamAmount[9] = _values[9];
    }

    function setRequiredTeamUsers(
        uint256[10] memory _values
    ) external onlyOwner onlyDev {
        requiredTeamUsers[0] = _values[0];
        requiredTeamUsers[1] = _values[1];
        requiredTeamUsers[2] = _values[2];
        requiredTeamUsers[3] = _values[3];
        requiredTeamUsers[4] = _values[4];
        requiredTeamUsers[5] = _values[5];
        requiredTeamUsers[6] = _values[6];
        requiredTeamUsers[7] = _values[7];
        requiredTeamUsers[8] = _values[8];
        requiredTeamUsers[9] = _values[9];
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