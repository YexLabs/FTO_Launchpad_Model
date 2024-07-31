import { Contract } from 'ethers';
import { deployContracts } from './deployment';

describe('Test', function () {
  let usdt: Contract;
  let yexFTOFactory: Contract;
  let yexFTOFacade: Contract;
  let henloDexFactory: Contract;

  before('Deploy Contracts', async () => {
    ({ usdt, yexFTOFactory, yexFTOFacade, henloDexFactory } =
      await deployContracts());

    console.log('usdt address: ', usdt.address);
    console.log('yexFTOFactory address: ', yexFTOFactory.address);
    console.log('yexFTOFacade address: ', yexFTOFacade.address);
    console.log('henloDexFactory address: ', henloDexFactory.address);
  });

  it('test1', async () => {
    console.log('test1 log');
  });

  it('test2', async () => {
    console.log('test2 log');
  });
});
