function calculateStakingReturns(initialAmount, totalSecondsStaked) {
    const apy = 0.20; // Annual Percentage Yield (APY)
    let amount = initialAmount;
    let rewardPerSecond = initialAmount * apy / 365 / 24 / 60 / 60; // Initial reward per second

    // Calculate the daily APY
    const dailyApy = apy / 365;

    for (let day = 0; day < 5; day++) {
        // Calculate reward per second based on the new amount
        const rewardPerSecondForDay = rewardPerSecond * amount;
        // Add the reward earned for each second in a day
        amount += rewardPerSecondForDay * (24 * 60 * 60);
        // Compound the amount by 1% each day
        amount *= 1.01;
        // Add the daily interest to the amount
        amount += amount * dailyApy;
        // Update reward per second for the next day
        rewardPerSecond = rewardPerSecondForDay;
    }

    return amount.toFixed(2); // Return the final amount rounded to 2 decimal places
}

// Example usage
const initialInvestment = 95;
const totalSecondsStaked = 5 * 24 * 60 * 60; // 5 days in seconds
const finalAmount = calculateStakingReturns(initialInvestment, totalSecondsStaked);
console.log("Final amount after staking for 5 days:", finalAmount, "tokens");

