import { ethers } from 'ethers';

export const FTOParams = {
  NAME: 'Test Token',
  SYMBOL: 'TST',
  AMOUNT: ethers.utils.parseEther('1000'),
  LAUNCHED_TOKEN_PERCENT: 50,
  RAISING_CYCLE: 86400, // 1 day
  DATA: '0x',
};

export const Status = {
  Success: 0,
  Failed: 1,
  Paused: 2,
  Processing: 3,
};
