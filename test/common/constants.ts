import { ethers } from 'ethers';

export const FTOParams = {
  NAME: 'Test Token',
  SYMBOL: 'TST',
  AMOUNT: ethers.utils.parseEther('1000'),
  LAUNCHED_TOKEN_PERCENT: 50,
  RAISING_CYCLE: 86400, // 1 day
  DATA: '0x',
};
