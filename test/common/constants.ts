export const FTOParams = {
  NAME: 'Test Token',
  SYMBOL: 'TST',
  AMOUNT: ethers.utils.parseUnits('1000000000', 18),
  LAUNCHED_TOKEN_PERCENT: 50,
  RAISING_CYCLE: 100,
  DATA: '0x',
};

export const Status = {
  Success: 0,
  Failed: 1,
  Paused: 2,
  Processing: 3,
};
