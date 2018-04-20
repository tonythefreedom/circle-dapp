pragma solidity ^0.4.16;

// 소유자 관리용 계약
contract Owned {
    // 상태 변수
    address public owner; // 소유자 주소
    
    // 소유자 한정 메서드용 수식자
    modifier onlyOwner() { 
        require(msg.sender == owner);
        _; 
    }
    
    // 소유자 변경 시 이벤트
    event TransferOwnership(address oldaddr, address newaddr);
    
    // 생성자
    function Owned() public{
        owner = msg.sender; // 처음에 계약을 생성한 주소를 소유자로 한다
    }
    
    // (1) 소유자 변경
    function transferOwnership(address _new) public onlyOwner {
        address oldaddr = owner;
        owner = _new;
        emit TransferOwnership(oldaddr, owner);
    }
}

// (2) 회원 관리용 계약
contract Members is Owned {
    // (3) 상태 변수 선언
    address public coin; // 토큰(가상 화폐) 주소
    MemberStatus[] public status; // 회원 등급 배열
    mapping(address => History) public tradingHistory; // 회원별 거래 이력
     
    // (4) 회원 등급용 구조체
    struct MemberStatus {
        string name; // 등급명
        uint256 times; // 최저 거래 회수
        uint256 sum; // 최저 거래 금액
        int8 rate; // 캐시백 비율
    }
    // 거래 이력용 구조체
    struct History {
        uint256 times; // 거래 회수
        uint256 sum; // 거래 금액
        uint256 statusIndex; // 등급 인덱스
    }
 
    // (5) 토큰 한정 메서드용 수식자
    modifier onlyCoin() { 
        require(msg.sender == coin); 
        _; 
    }
     
    // (6) 토큰 주소 설정
    function setCoin(address _addr) public onlyOwner {
        coin = _addr;
    }
     
    // (7) 회원 등급 추가
    function pushStatus(string _name, uint256 _times, uint256 _sum, int8 _rate) public onlyOwner {
        status.push(MemberStatus({
            name: _name,
            times: _times,
            sum: _sum,
            rate: _rate
        }));
    }
 
    // (8) 회원 등급 내용 변경
    function editStatus(uint256 _index, string _name, uint256 _times, uint256 _sum, int8 _rate) public onlyOwner {
        if (_index < status.length) {
            status[_index].name = _name;
            status[_index].times = _times;
            status[_index].sum = _sum;
            status[_index].rate = _rate;
        }
    }
     
    // (9) 거래 내역 갱신
    function updateHistory(address _member, uint256 _value) public onlyCoin {
        tradingHistory[_member].times += 1;
        tradingHistory[_member].sum += _value;
        // 새로운 회원 등급 결정(거래마다 실행)
        uint256 index;
        int8 tmprate;
        for (uint i = 0; i < status.length; i++) {
            // 최저 거래 횟수, 최저 거래 금액 충족 시 가장 캐시백 비율이 좋은 등급으로 설정
            if (tradingHistory[_member].times >= status[i].times &&
                tradingHistory[_member].sum >= status[i].sum &&
                tmprate < status[i].rate) {
                index = i;
            }
        }
        tradingHistory[_member].statusIndex = index;
    }

    // (10) 캐시백 비율 획득(회원의 등급에 해당하는 비율 확인)
    function getCashbackRate(address _member) public constant returns (int8 rate) {
        rate = status[tradingHistory[_member].statusIndex].rate;
    }
}
     
// (11) 회원 관리 기능이 구현된 가상 화폐
contract CircleCoin is Owned{
    // 상태 변수 선언
    string public name; // 이스포츠 경기 이름
    string public symbol; // 이스포츠 경기 토큰 단위
    uint8 public decimals; // 소수점 이하 자릿수
    uint256 public totalSupply; // 토큰 총량
    uint8 public ScoreOfA; // 이스포츠 A 팀 점수
    uint8 public ScoreOfB; // 이스포츠 B 팀 점수
    mapping (address => uint256) public balanceOf; // 각 주소의 잔고
    mapping (address => int8) public blackList; // 블랙리스트
    mapping (address => Members) public members; // 각 주소의 회원 정보
     
    // 이벤트 알림
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Blacklisted(address indexed target);
    event DeleteFromBlacklist(address indexed target);
    event RejectedPaymentToBlacklistedAddr(address indexed from, address indexed to, uint256 value);
    event RejectedPaymentFromBlacklistedAddr(address indexed from, address indexed to, uint256 value);
    event Cashback(address indexed from, address indexed to, uint256 value);
     
    // 생성자
    function CircleCoin(uint256 _supply, string _name, string _symbol, uint8 _decimals) public {
        balanceOf[msg.sender] = _supply;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _supply;
    }
 
    // 주소를 블랙리스트에 등록
    function blacklisting(address _addr) public onlyOwner {
        blackList[_addr] = 1;
        emit Blacklisted(_addr);
    }
 
    // 주소를 블랙리스트에서 해제
    function deleteFromBlacklist(address _addr) public onlyOwner {
        blackList[_addr] = -1;
        emit DeleteFromBlacklist(_addr);
    }
 
    // 회원 관리 계약 설정
    function setMembers(Members _members) public {
        members[msg.sender] = Members(_members);
    }
 
    // 송금
    function transfer(address _to, uint256 _value) public {
        // 부정 송금 확인
        require(balanceOf[msg.sender] > _value);
        require(balanceOf[_to] + _value > balanceOf[_to]);

        // 블랙리스트에 존재하는 계정은 입출금 불가
        if (blackList[msg.sender] > 0) {
            emit RejectedPaymentFromBlacklistedAddr(msg.sender, _to, _value);
        } else if (blackList[_to] > 0) {
            emit RejectedPaymentToBlacklistedAddr(msg.sender, _to, _value);
        } else {
            // (12) 캐시백 금액을 계산(각 대상의 비율을 사용)
            uint256 cashback = 0;
            if(members[_to] > address(0)) {
                cashback = _value / 100 * uint256(members[_to].getCashbackRate(msg.sender));
                members[_to].updateHistory(msg.sender, _value);
            }
 
            balanceOf[msg.sender] -= (_value - cashback);
            balanceOf[_to] += (_value - cashback);
 
            emit Transfer(msg.sender, _to, _value);
            emit Cashback(_to, msg.sender, cashback);
        }
    }
}

// (1) 크라우드 배팅 
contract CrowdBetting is Owned {
    // (2) 상태 변수
    uint256 public fundingGoal; // 목표 금액
    uint256 public deadline; // 기한
    uint256 public price; // 토큰 기본 가격
    uint256 public transferableToken; // 전송 가능 토큰
    uint256 public soldToken; // 판매된 토큰
    uint256 public startTime; // 개시 시간
    CircleCoin public tokenReward; // 지불에 사용할 토큰

    bool public FinishGame; // 게임 종료 플래그
    bool public MatchFunders; // 배팅 성공자 추출 플래그
    uint public MatchEth = 0; // 배팅 성공자 종합 이더리움
    uint8 public FinalScoreOfA; // 최종 A팀 스코어
    uint8 public FinalScoreOfB; // 최종 B팀 스코어
    uint public count = 0; // 배팅 참여자
    bool public fundingGoalReached; // 목표 도달 플래그
    bool public isOpened; // 크라우드 세일 개시 플래그
    mapping (address => Property) public fundersProperty; // 자금 제공자의 자산 정보
    mapping (uint => address) public ToCountGetaddress; // 참여자 address


    // (3) 자산정보 구조체
    struct Property {
        uint256 paymentEther; // 지불한 Ether
        uint8 BettingScoreOfA; // A팀 예상 스코어
        uint8 BettingScoreOfB; // B팀 예상 스코어
        uint256 reservedToken; // 예상 받는 토큰
        bool MatchScore; // 성공 플래그
        bool withdrawed; // 인출 플래그
    }
    
    // 배열
    Property[] public Propertys;

 
    // (4) 이벤트 알림
    event CrowdsaleStart(uint fundingGoal, uint deadline, uint transferableToken, address beneficiary);
    event ReservedToken(address backer, uint amount, uint token);
    event CheckGoalReached(address beneficiary, uint fundingGoal, uint amountRaised, bool reached, uint raisedToken);
    event WithdrawalTokenAndEther(address addr, uint amount, uint etherAmount ,bool result);
    event WithdrawalEther(address addr, uint amount, bool result);
    event BettingScore(address addr, uint amount, uint8 FinalScoreOfA, uint8 FinalScoreOfB);
 
    // (5) 수식자
    modifier afterDeadline() { 
        require(now >= deadline);
        _; 
    }
 
    // (6) 생성자
    function CrowdBetting (
        uint _fundingGoalInEthers,
        uint _transferableToken,
        uint _amountOfTokenPerEther,
        CircleCoin _addressOfTokenUsedAsReward
    ) public {
        fundingGoal = _fundingGoalInEthers * 1 ether;
        price = 1 ether / _amountOfTokenPerEther;
        transferableToken = _transferableToken;
        tokenReward = CircleCoin(_addressOfTokenUsedAsReward);
    }

    // (7) Ether 받기
    function Betting(uint8 _BettingScoreOfA, uint8 _BettingScoreOfB) payable public {
        // 개시 전 또는 기간이 지난 경우 예외 처리 
        require(isOpened || now < deadline);

        // 받은 Ether와 판매 예정 토큰
        uint amount = msg.value;
        uint token = amount / price;
        
        // 판매 예정 토큰의 확인(예정 수를 초과하는 경우는 예외 처리)
        require(token != 0 || soldToken + token < transferableToken);
        // 자산 제공자의 자산 정보 변경

        // Push 자산 제공자 구조 배열 추가
        Propertys.push(
            Property(amount, _BettingScoreOfA, _BettingScoreOfB, token, false, false)
            );
        
        // 매핑 address 얻기 위한 
        ToCountGetaddress[count] = msg.sender;

        count++;

        fundersProperty[msg.sender].paymentEther += amount;
        fundersProperty[msg.sender].reservedToken += token;

        soldToken += token;
        emit ReservedToken(msg.sender, amount, token);
    }
 
    // (8) 개시(토큰이 예정한 수 이상 있다면 개시)
    function start(uint _durationInMinutes) public onlyOwner {
        require(fundingGoal == 0 || price == 0 || transferableToken == 0 || tokenReward == address(0) || _durationInMinutes == 0 || startTime != 0);
        
        if (tokenReward.balanceOf(this) >= transferableToken) {
            startTime = now;
            deadline = now + _durationInMinutes * 1 minutes;
            isOpened = true;
            emit CrowdsaleStart(fundingGoal, deadline, transferableToken, owner);
        }
    }

 
    // (10) 남은 시간(분 단위)과 목표와의 차이(eth 단위), 토큰 확인용 메서드
    function getRemainingTimeEthToken() public constant returns(uint min, uint shortage, uint remainToken) {
        if (now < deadline) {
            min = (deadline - now) / (1 minutes);
        }
        shortage = (fundingGoal - address(this).balance) / (1 ether);
        remainToken = transferableToken - soldToken;
    }
 
    // (11) 목표 도달 확인(기한 후 실시 가능)
    function checkGoalReached() public afterDeadline {
        if (isOpened) {
            // 모인 Ether와 목표 Ether 비교
            if (address(this).balance >= fundingGoal) {
                fundingGoalReached = true;
            }
            isOpened = false;
            emit CheckGoalReached(owner, fundingGoal, address(this).balance, fundingGoalReached, soldToken);
        }
    }

    // (12) 주최자의 이스포츠 경기 종료 결과 입력 (스코어 점수)
    function FinsihESport(uint8 _FinalScoreOfA, uint8 _FinalScoreOfB) public onlyOwner {
        require(isOpened);
        
        FinalScoreOfA = _FinalScoreOfA;
        FinalScoreOfB = _FinalScoreOfB;
        FinishGame = true;
    }
 
    function MatchBetting() public onlyOwner{
        require(FinishGame);

        for (uint i = 0; i <= count; i++) {
            if (Propertys[i].BettingScoreOfA == FinalScoreOfA && Propertys[i].BettingScoreOfB == FinalScoreOfB){ 
                MatchEth += Propertys[i].paymentEther;
            }
        }
    }
 
    // (13) 자금 제공자용 인출 메서드(세일 종료 후 실시 가능)
    function withdrawal() public {
        if (isOpened) return;
        // 이미 인출된 경우 예외 처리 
        require(fundersProperty[msg.sender].withdrawed);
        
        // 경기종료 유무
        require(FinishGame);

        if (FinishGame){

            if (FinalScoreOfA == fundersProperty[msg.sender].BettingScoreOfA && FinalScoreOfB == fundersProperty[msg.sender].BettingScoreOfB) {
                
                // 본인이 투자한 이더리움 만큼의 %비율을 가짐.
                // ex) 15 , 5, 30, 50 [Betting : 15,5]
                // address(this).balance * ( fundersProperty[msg.sender].paymentEther /  allEth ) 
                // 100 * (15 / 20) = 75
                // 100 * (5 / 20) = 25
                
                tokenReward.transfer(msg.sender, fundersProperty[msg.sender].reservedToken);
                uint rate = address(this).balance * (fundersProperty[msg.sender].paymentEther / MatchEth);

                msg.sender.transfer(rate);

                fundersProperty[msg.sender].withdrawed = true;
                emit WithdrawalTokenAndEther(
                    msg.sender,
                    fundersProperty[msg.sender].reservedToken,
                    rate,
                    fundersProperty[msg.sender].withdrawed
                );
            }
        }
    }
} 