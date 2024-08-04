import { Contract, BigNumber } from 'ethers';
import { FTOParams } from './constants';

export const createFTO = async (
  yexFTOFactory: Contract,
  tokenLauncher: SignerWithAddress,
  params: {
    raisedToken: string;
    name?: string;
    symbol?: string;
    amount?: BigNumber;
    launchedTokenPercent?: number;
    dexRouter: string;
    raisingCycle?: number;
    data?: string;
  },
) => {
  return await yexFTOFactory
    .connect(tokenLauncher)
    .createFTO(
      params.raisedToken,
      params.name || FTOParams.NAME,
      params.symbol || FTOParams.SYMBOL,
      params.amount || FTOParams.AMOUNT,
      params.launchedTokenPercent || FTOParams.LAUNCHED_TOKEN_PERCENT,
      params.dexRouter,
      params.raisingCycle || FTOParams.RAISING_CYCLE,
      params.data || FTOParams.DATA,
    );
};

export async function generateSignersAndAmounts(
  amounts: number[],
  decimal: number,
): Promise<[SignerWithAddress[], ethers.BigNumber[]]> {
  const allSigners = await ethers.getSigners();
  const requiredSigners = allSigners.slice(2, 2 + amounts.length);
  const bigAmounts = amounts.map((amount) =>
    ethers.utils.parseUnits(amount.toString(), decimal),
  );

  return [requiredSigners, bigAmounts];
}
