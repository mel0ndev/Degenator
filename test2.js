function calculateStakingReturns(initialAmount, days) {
    const apy = 0.20; // Annual Percentage Yield (APY)
    let amount = initialAmount;

    for (let i = 0; i < days; i++) {
        // Compound the amount by 1% each day
        amount *= 1.01;
        // Calculate the daily APY
        const dailyApy = apy / 365;
        // Add the daily interest to the amount
        amount += amount * dailyApy;
    }

    return amount.toFixed(2); // Return the final amount rounded to 2 decimal places
}

// Example usage
const initialInvestment = 95;
const daysStaked = 60; 
const finalAmount = calculateStakingReturns(initialInvestment, daysStaked);
console.log("Final amount after staking for", daysStaked, "days:", finalAmount, "tokens");

