pragma solidity ^0.5.0; 

contract Registration{
    
    address public govermentEntity; 
    uint manufacturerIdenfiter; 
    
    struct Manufacturer{
        bool exist; 
        uint idenftifier; 
    }
   
   
   
    mapping(address=>bool) Buyers; 
    mapping(address=>bool) Sellers; 
    mapping(address=>bool) sortingMachines;
    mapping(address=> Manufacturer) Manufacturers; 
    

    constructor() public{
     govermentEntity = msg.sender; 
     manufacturerIdenfiter = 0; 
    }
    
    modifier onlyGovermentEntity{
        require( msg.sender == govermentEntity,
        "Entity is not authorized to register stakeholders.");
        _;
    }
    
  
 
    event ManufactuererRegistered(address Manufacturer, string manufacturerLocation, string manufacturerName); 
    event BuyerRegistered(address buyer, string buyerName, string buyerLocation, string buyerBusinessType);
    event SellerRegistered(address seller, string sellerLocation, string sellerName);
    event SortingMachineRegistered(address sortingMachine, address seller);
    
    
    
    function registerManufactuerer (address manufactuerer, string memory manufacturerLocation, string memory manufacturerName) public onlyGovermentEntity
    {
        require(!Manufacturers[manufactuerer].exist, 
        "Manufactuerer is registered already"); 
        Manufacturers[manufactuerer].exist = true;
        Manufacturers[manufactuerer].idenftifier = manufacturerIdenfiter;
        
        manufacturerIdenfiter++; 
        
        emit ManufactuererRegistered(manufactuerer, manufacturerLocation, manufacturerName);
    }
    
    
    function registerBuyer (address buyer, string memory buyerName, string memory buyerLocation, string memory buyerBusinessType) public onlyGovermentEntity 
    {
        require(!Buyers[buyer],
        "Buyer is registered already"); 
        Buyers[buyer] = true;
    
        emit BuyerRegistered(buyer, buyerName, buyerLocation, buyerBusinessType);
    }
   
    function registerSeller (address seller, string memory sellerLocation, string  memory sellerName) public onlyGovermentEntity {
        require(!Sellers[seller], 
        "Seller is registered already"); 
        Sellers[seller] = true;
        
        emit SellerRegistered(seller, sellerLocation, sellerName);
        }
    
     function registerSortingMachine (address sortingMachine, address seller) public onlyGovermentEntity {
        require(!sortingMachines[sortingMachine], 
        "Sorting Machine is registered already");
        sortingMachines[sortingMachine] = true;
        
        emit SortingMachineRegistered(sortingMachine, seller);
         
     }
    

    // Used in BottleProductionSC
   function isManufactuererExist(address manufactuerer) external view returns (bool){
        return Manufacturers[manufactuerer].exist;
       }
       
       // Used in PlasticBale SC
    function isBuyerExist(address buyer) external view returns (bool){
        return Buyers[buyer];
    }
    
     // Used in BottleProductionSC
   function getManufactuererIdentifier(address manufacturer) external view returns (uint){
        return Manufacturers[manufacturer].idenftifier;
   }
    
    
    // Used in Tracking SC 
    function isSortingMachineExist(address sortingMachine) external view returns (bool){ 
        return sortingMachines[sortingMachine]; 
    }
}

contract BottleProduction {

    address public bottleAddress;
    address public manufactuerer;
    uint public ManufacturerID;
    address registrationAddress; 
    Registration R; 
    
    
    struct PlasticBottle {
        address  bottleAddress; 
        uint bottleManufacturer;
        uint bottlePlasticType;
        uint bottleColor;
        uint bottleSize;
    }
    

    constructor(address _registrationAddress) public{
        manufactuerer = msg.sender; 
        registrationAddress = _registrationAddress;
        R = Registration(_registrationAddress); 
    }
    

    event bottleRegistered(address plasticBottleAddress, uint ManufacturerID, uint bottlePlasticType, uint bottleColor, uint bottleSize, uint time); 
    
    mapping (address => PlasticBottle) manufacturedBottles; 
    
    modifier onlyRegisteredManufacturers{ 
    
        require(R.isManufactuererExist(msg.sender), 
        "Manufacturer not authorized to register bottles");
        _;
    }
    
    function registerBottle (uint bottlePlasticType, uint bottleColor, uint bottleSize) public onlyRegisteredManufacturers{ 
       
        //get id of manufacturer from register contract
        ManufacturerID = R.getManufactuererIdentifier(manufactuerer);
        
        // gets generated address for bottle
        bottleAddress = generateUniqueBottleAddress(ManufacturerID, bottlePlasticType, bottleColor, bottleSize);
        
        manufacturedBottles[bottleAddress] = PlasticBottle(bottleAddress, ManufacturerID, bottlePlasticType, bottleColor, bottleSize);
    
        emit bottleRegistered(bottleAddress, ManufacturerID, bottlePlasticType, bottleColor, bottleSize, now);
    }
    
     function generateUniqueBottleAddress (uint _ManufacturerID, uint bottlePlasticType, uint bottleColor, uint bottleSize) internal view returns (address) {
        //https://gist.github.com/techbubble/8f9db0f3ddd83ae0b1786ccf7805c461
        
        //generates a unique 20 byte value
        bytes20 b = bytes20(keccak256(abi.encodePacked(msg.sender, now)));
        
        uint addr = 0;
        for (uint index = b.length-1; index > 1; index--) {// used to extract the least significant 16 bytes
            addr += uint(uint8(b[index])) * ( 16 ** ((b.length - index - 1)*2));
        }
        
        //this will append the ID's to the bottle address 0x(manufact)(type)(color)(size)...etc
        uint firstMSByte= _ManufacturerID*16 +bottlePlasticType;
        uint secondMSByte= bottleColor*16 +bottleSize;
        addr += firstMSByte * ( 16 ** ((19)*2));
        addr += secondMSByte * ( 16 ** ((18)*2));
        
        return address(addr);
    }

} 

contract Tracking{

    string IPFSHash;
    address registrationAddress; 
    Registration R; 
    //variables for counting plastic bottles scanned in the sorting machine 
    uint public bottlesSorted;  
    uint public plasticBaleSize;  
    
    address [] public plasticBale; // PlaticBale is a collection of plastic bottle addresses
    address payable [] public plasticBaleContributorsAddresses; 
    address [] public deployedPlasticBales;
    
     
    constructor(address _registrationAddress) public{
        IPFSHash = 'NoImage';
        bottlesSorted = 0;
        registrationAddress = _registrationAddress;
        R = Registration(_registrationAddress); 
    }
    
   
    event plasticBottleDisposed(address indexed recycler, address indexed plasticBottle, string wasteManagmentStage, uint  time);
    event plasticBottleSorted(address indexed seller, address indexed plasticBottle, string  wasteManagmentStage, uint time); 
    event plasticBaleCompleted(address [] plasticBale, address payable [] plasticBaleContributorsAddresses,  address indexed seller, 
    PlasticBale plasticbale, uint bottlesInBaleNo, string IPFSHash,  uint time); 
    
    
    modifier sortingMachineOnly{
        require(R.isSortingMachineExist(msg.sender), 
          "Sorting Machine is not authorized to sort bottles");
          _;
         }
   
   mapping(address=>address payable) bottleToRecycler; 
    
    

    function setPlasticBaleSize (uint _plasticBaleSize) public  sortingMachineOnly {  
        plasticBaleSize = _plasticBaleSize;
          }
          
    function setIPFSHash (string memory  _IPFSHash) public sortingMachineOnly { 
        IPFSHash = _IPFSHash;
          }     
    
    
    function updateDisposedStage (address plasticBottle) public{ 
        bottleToRecycler[plasticBottle] = msg.sender; 
        emit plasticBottleDisposed (msg.sender, plasticBottle, 'Disposed', now);
    }
    
    function updateSortedStage (address plasticBottle, address payable seller) public sortingMachineOnly{ 
        
       plasticBaleContributorsAddresses.push(bottleToRecycler[plasticBottle]); 
       plasticBale.push(plasticBottle);
       bottlesSorted++;
    
    
       emit plasticBottleSorted(seller, plasticBottle, 'Sorted', now);
      
      if(bottlesSorted == plasticBaleSize )
         createPlasticBale(seller, IPFSHash); 
    }
    
    
    function createPlasticBale(address payable seller, string memory _IPFSHash ) public { 
         bottlesSorted = 0; //reseting the counter
         PlasticBale newBale = new PlasticBale(plasticBale, plasticBaleContributorsAddresses, seller, _IPFSHash, registrationAddress);
         deployedPlasticBales.push(address(newBale)); 
         emit plasticBaleCompleted (plasticBale, plasticBaleContributorsAddresses, seller, newBale, plasticBaleSize, _IPFSHash,  now); 
    }
    
 
}

contract PlasticBale{
    

     address[] public plasticBale; 
     address payable[] public contributors; 
     address payable[] public tempArray; 
     uint public contribution;  //Added here
     string public baleHash; //(new)
     
    address registrationAddress; 
    Registration R; 
   
   
      bool public isOpen; 
      uint public highestBid; 
      address payable public highestBidder; 
      uint public startTime; 
      uint public endTime; 
      address payable public auctionOwner;
      uint totalBidders; 
  
  struct buyer{
      bool isExist; 
      uint placedBids; 
      uint deposit; 
  }
  
  
  
  mapping(address=>buyer) bidder; 
  
 
    constructor(address[] memory _plasticBale, address payable[] memory _contributors, address payable seller,
    string memory _baleHash, address _registrationAddress ) public { 
      plasticBale = _plasticBale; 
      contributors = _contributors; 
      auctionOwner = seller; 
      baleHash = _baleHash; 
      totalBidders = 0; 
      registrationAddress = _registrationAddress;
      R = Registration(_registrationAddress); 
      }  
    
    
    modifier onlyOwner{
        require(msg.sender == auctionOwner, 
        "Auction owner is not authorized"); 
        _; 
    }
    
    modifier onlyBidder{
        require(R.isBuyerExist(msg.sender), 
        "Bidder is not registered"); 
        _;                                                                      
    }
    
    event bidderRegistered (address indexed baleAddress, address indexed bidderAddress); 
    event auctionStarted (address indexed baleAddress, uint startingAmount, uint closingTime, string baleHash); 
    event bidPlaced(address indexed baleAddress, address indexed biddeAddress, uint amount);
    event bidderExited(address indexed baleAddress, address indexed bidderAddress); 
    event auctionEnded (address indexed baleAddress,address highestBidder, uint highestBid , uint closingTime); 
    event recyclerRewarded(address indexed recycler, uint etherReward);
    event plasticBottleSold(address buyer, address indexed plasticBottleAddress, string status, uint time); 
    
    
    function addBidder(address bidderAddr) onlyBidder public { //Fixed
        
    require(bidder[bidderAddr].isExist == false, 
    "Bidder already joined the Auction.");
    totalBidders++; 
    bidder[bidderAddr] = buyer(true, 0, 0); 
    
    emit bidderRegistered(address(this),bidderAddr);
        
    }
    
    function startAuction(uint closingTime, uint startPrice) onlyOwner payable public {
        
        require(isOpen == false,
        "Auction is already open."); 
        
        require( closingTime > now,
        "Auction time can only be set in future.");
        
        isOpen = true; 
        highestBid = startPrice; 
        highestBidder = address(0); 
        startTime = now; 
        endTime = closingTime; 
       
       // Contract address is the bale address 
        emit auctionStarted(address(this), startPrice, closingTime, baleHash);
    }
    
    function placeBid( uint amount)  onlyBidder payable public{
        
        require(bidder[msg.sender].isExist, 
        "Buyer Address is not registered."); 
        
        require(isOpen,"Auction is not opened.");
        
        // To place a bid, amount sent has to be bigger than the highest bid 
        require(amount > highestBid, "Place a higher bid."); 
        
        //Validating the amount of wei sent with the transaction 
        require(msg.value == amount, "Insufficient Deposit."); 
        
        bidder[msg.sender].placedBids++; 
        bidder[msg.sender].deposit += msg.value; 
        
        highestBid = amount; 
        highestBidder= msg.sender; 
        
        emit bidPlaced(address(this), msg.sender, amount); 
        
    }
    
    function exitAuction() onlyBidder public {
        
        // Buyers can exit auction if no bids are placed yet 
        require(bidder[msg.sender].placedBids == 0,
        "Buyer has placed a bid already."); 
        bidder[msg.sender] = buyer(false, 0 ,0); 
        totalBidders--; 
        emit bidderExited(address(this), msg.sender); 
    }
    
    
    function endAuction() public{
        
        require( isOpen,
        "Auction is not avalible");
        
        require (endTime < now, 
        "Auction can not be closed at this time");
        
        require(highestBidder != address(0),
        "No bids have been placed"); 
        
        isOpen = false; 
        
        uint halfAmount = highestBid/2;
    
        // Pay the seller 
        (auctionOwner).transfer(halfAmount); 
        
        //Calculate each participants' share & reward recyclers 

        uint contributionRate =0; 
        uint reward; 
        
        //1. Filter unique recyclers from contributors array 
        
        for(uint i=0; i < contributors.length; i++){
                uint j;
             for(j=0; j < i; j++)
                  if(contributors[i] == contributors[j])
                      break;
                if(i==j)
                tempArray.push(contributors[i]);
              }
        
        //2. Find number of contribution 

        for(uint i=0; i < tempArray.length; i++){
            contribution=0;
             for(uint z=0; z < contributors.length; z++){
                  if(tempArray[i] == contributors[z])
                      contribution++;
             }
             contribution = contribution *100; 
             contributionRate = contribution / (plasticBale.length);
             reward = ((contributionRate * halfAmount)/ 100)+1;
             tempArray[i].transfer(reward); 
             rewardRecycler(tempArray[i], reward); 
    
        }
          
          
          for(uint i=0; i< plasticBale.length; i++)
          updateSoldStage(highestBidder, plasticBale[i]); 
          
        emit auctionEnded(address(this), highestBidder, highestBid , now); 
    
    }
    
    function updateSoldStage(address buyerAddress, address plasticBottleAddress) public {
        
        emit plasticBottleSold(buyerAddress, plasticBottleAddress, "sold", now); 
    }
    
    function rewardRecycler(address recycler, uint reward) public {
        
        emit recyclerRewarded(recycler, reward);
    }
 
    
}