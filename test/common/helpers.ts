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

export function calculateLpAmount(
  amounts: BigNumber[],
  index: number,
  totalLp: BigNumber,
): BigNumber {
  const raisedTokenDeposit = amounts[index];
  const depositedRaisedToken = amounts.reduce(
    (acc, amount) => acc.add(amount),
    ethers.BigNumber.from(0),
  );
  return raisedTokenDeposit.mul(totalLp.div(2)).div(depositedRaisedToken);
}

export function calculateLaunchedTokenAmount(
  amounts: BigNumber[],
  index: number,
): BigNumber {
  const raisedTokenDeposit = amounts[index];
  const depositedRaisedToken = amounts.reduce(
    (acc, amount) => acc.add(amount),
    ethers.BigNumber.from(0),
  );
  const poolLaunchedTokenAmount = FTOParams.AMOUNT.sub(
    FTOParams.AMOUNT.mul(FTOParams.LAUNCHED_TOKEN_PERCENT).div(100),
  );
  return raisedTokenDeposit
    .mul(poolLaunchedTokenAmount)
    .div(depositedRaisedToken);
}

export function calculateFeeAmount(
  lpBalance: BigNumber,
  feePercent: number,
): BigNumber {
  const totalLP = lpBalance.mul(100).div(100 - feePercent);
  return totalLP.sub(lpBalance);
}
