pragma solidity ^0.4.18;

import './safeMath.sol';

contract ColdStaking {

    using SafeMath for uint256;

    event StartStaking(address addr, uint256 value, uint256 weight, uint256 init_block);

    event WithdrawStake(address staker, uint256 weight);

    event Claim(address staker, uint256 reward);

    event FirstStakeDonation(address _address, uint256 value);


    struct Staker
    {
        uint256 weight;
        uint256 init_block;
    }

    uint256 public staking_pool;

    uint256 public staking_threshold = 0 ether;

    //uint256 public round_interval    = 172800; // approx. 1 month in blocks
    //uint256 public max_delay      = 172800 * 12; // approx. 1 year in blocks


    /// TESTING VALUES
    uint256 public round_interval = 200; // approx. 1 month in blocks
    uint256 public max_delay = 7 * 6000; // approx. 1 year in blocks

    mapping(address => Staker) staker;
    mapping(address => bool) private muted;


    function() public payable
    {
        // No donations accepted to fallback!
        // Consider value deposit is an attempt to become staker.
        start_staking();
    }

    function start_staking() public payable
    {
        assert(msg.value >= staking_threshold);
        staking_pool = staking_pool.add(msg.value);

        Staker storage _staker = staker[msg.sender];

        _staker.weight = _staker.weight.add(msg.value);
        _staker.init_block = block.number;

        StartStaking(
            msg.sender,
            msg.value,
            _staker.weight,
            _staker.init_block
        );


    }


    function First_Stake_donation() public payable {

        FirstStakeDonation(msg.sender, msg.value);


    }

    function claim_and_withdraw() public
    {
        claim();
        withdraw_stake();
    }

    function withdraw_stake() public only_staker mutex(msg.sender)
    {

        Staker storage _staker = staker[msg.sender];
        uint256 _weight = _staker.weight;
        msg.sender.transfer(_weight);
        staking_pool = staking_pool.sub(_weight);
        _staker.weight = 0;
        WithdrawStake(msg.sender, _weight);


    }

    function claim() public only_staker mutex(msg.sender)
    {
        require(block.number >= staker[msg.sender].init_block.add(round_interval));

        uint256 _reward = stake_reward(msg.sender);
        msg.sender.transfer(_reward);
        staker[msg.sender].init_block = block.number;

        Claim(msg.sender, _reward);
    }

    function stake_reward(address _addr) public view returns (uint256 _reward)
    {
        return (reward() * ((block.number - staker[_addr].init_block) / round_interval) * (staker[_addr].weight / (staking_pool + (staker[_addr].weight * (block.number - staker[_addr].init_block) / round_interval))));
    }

    function report_abuse(address _addr) public only_staker
    {
        assert(staker[_addr].weight > 0);
        assert(block.number > staker[_addr].init_block.add(max_delay));

        _addr.transfer(staker[msg.sender].weight);
        staker[_addr].weight = 0;
    }

    function reward() public view returns (uint256)
    {
        return address(this).balance.sub(staking_pool);
    }

    modifier only_staker
    {
        assert(staker[msg.sender].weight > 0);
        _;
    }

    modifier mutex(address _target)
    {
        if (muted[_target])
        {
            revert();
        }

        muted[_target] = true;
        _;
        muted[_target] = false;
    }

    ////////////// DEBUGGING /////////////////////////////////////////////////////////////


    function test() public pure returns (string)
    {
        return "success!";
    }

    function staker_info(address _addr) public view returns
    (uint256 weight, uint256 init, uint256 stake_time, uint256 _reward)
    {
        return (
        staker[_addr].weight,
        staker[_addr].init_block,
        block.number - staker[_addr].init_block,
        stake_reward(_addr)
        );
    }
}