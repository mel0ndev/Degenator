function calculateStakingReturns(initialAmount, rewardPerSecond, totalSecondsStaked) {
    const apy = 0.20; // Annual Percentage Yield (APY)
    let amount = initialAmount;

    // Calculate the number of days staked based on total seconds staked
    const daysStaked = totalSecondsStaked / (60 * 60 * 24);

    for (let i = 0; i < totalSecondsStaked; i++) {
        // Compound the amount by 1% each second
        amount *= 1.0001;
        // Calculate the daily APY
        const dailyApy = apy / (365 * 24 * 60 * 60); // APY per second
        // Add the daily interest to the amount
        amount += amount * dailyApy;
        // Add the reward per second
        amount += rewardPerSecond;
    }

    return amount.toFixed(2); // Return the final amount rounded to 2 decimal places
}

// Example usage
const initialInvestment = 95;
const rewardPerSecond = 0.00001; // Example reward per second
const secondsIn5Days = 5 * 24 * 60 * 60; // 5 days in seconds
const finalAmount = calculateStakingReturns(initialInvestment, rewardPerSecond, secondsIn5Days);
console.log("Final amount after staking for 5 days:", finalAmount, "tokens");

