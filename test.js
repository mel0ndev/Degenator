
function getAmounts(startingAmount, apy, timeStaked, bonusApy, duration) {
    const rps = getRewardPerSecond(95, 20);  
    bonusApy = bonusApy / 100; 
    const totalRewards = rps * timeStaked; 

    if (timeStaked < 3600) return startingAmount + totalRewards; 
    
    //in days
    const roundTrips = Math.floor(timeStaked / (3600 * 24)); 
    console.log(roundTrips); 
    
    //for initial trip
    let finalAmount = startingAmount + (getRewardPerSecond(startingAmount, apy) * (86400 * duration)); 
    //let finalAmount = startingAmount; 
    console.log('starting + rewards', finalAmount); 

    //for each subsequent trip, we need to add in the rewards for THAT day to the finalAmount variable
    for (let i = 0; i < roundTrips; i++) {
        finalAmount += finalAmount * bonusApy; 

        console.log("final after bonus", finalAmount); 

        if (roundTrips == 1) break; 

        let newRps = getRewardPerSecond(finalAmount, apy) * (86400 * duration); 
        console.log(newRps); 
        finalAmount += newRps;  
        console.log("final after new rps", finalAmount); 
    }

    //any leftover seconds get added at the end 
    const leftoverSeconds = timeStaked - roundTrips * 3600 * 24;  
    console.log(leftoverSeconds); 
    const leftoverSecondsRewardsRps = getRewardPerSecond(finalAmount, apy) * leftoverSeconds; 
    finalAmount += finalAmount * leftoverSecondsRewardsRps; 

    return finalAmount; 
}

function getRewardPerSecond(amount, apy) {
    const apyPercent = apy / 100; 
    const rps = amount * (apyPercent / 365 / 24 / 60 / 60); 
    return rps; 
}

const timeStaked = ((60 * 60 * 24) * 5); 
const duration = 1; //where 1 == 1 days
const amount = getAmounts(95_000, 20, timeStaked, 0.1, duration); 
console.log("amount out:", amount); 
