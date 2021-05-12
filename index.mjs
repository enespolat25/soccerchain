import { loadStdlib } from '@reach-sh/stdlib';
import * as backend from './build/index.main.mjs';

(async () => {
  const stdlib = await loadStdlib();
  const [ N, timeoutFactor ] =
    stdlib.standardUnit === 'ALGO' ? [ 5, 2 ] : [ 5, 2 ];

  const startingBalance = stdlib.parseCurrency(10);
  const accOrganiser = await stdlib.newTestAccount(startingBalance);
  const accBettor_arr = await Promise.all( Array.from({length: N}, () => stdlib.newTestAccount(startingBalance)) );
  const accAlice = await stdlib.newTestAccount(startingBalance);
  const accBob = await stdlib.newTestAccount(startingBalance);

  const fmt = (x) => stdlib.formatCurrency(x, 4);
  const getBalance = async (who) => fmt(await stdlib.balanceOf(who));
  const beforeAlice = await getBalance(accAlice);
  const beforeBob = await getBalance(accBob);

  const ctcOrganiser = accOrganiser.deploy(backend);
  const ctcInfo = ctcOrganiser.getInfo();

  const OUTCOME = ['Alice wins', 'Bob wins', 'Timeout'];
  const Common = (Who) => ({
      showOutcome: (outcome, forA, forB) => {
        if ( outcome == 2 ) {
          console.log(`${Who} saw the timeout`); }
        else {
          console.log(`${Who} saw a ${forA}-${forB} outcome: ${OUTCOME[outcome]}`);
        }
  } });

  await Promise.all([
    backend.Organiser(ctcOrganiser, {
      ...Common('Organiser'),
      getParams: () => ({
        wagerPrice: stdlib.parseCurrency(5),
        deadline: N*timeoutFactor,
        aliceAddr: accAlice,
        bobAddr: accBob,
      }),
    }),
  ].concat(
    accBettor_arr.map((accBettor, i) => {
      const ctcBettor = accBettor.attach(backend, ctcInfo);
      const Who = `Bettor #${i}`;
      const vote = Math.random() < 0.5;
      let voted = false;
      return backend.Bettor(ctcBettor, {
        ...Common(Who),
        getVote: (() => vote),
        bettorWas: ((voterAddr) => {
          if ( stdlib.addressEq(voterAddr, accBettor) ) {
            console.log(`${Who} voted: ${vote ? 'Alice' : 'Bob'}`);
            voted = true;
          } } ),
        shouldVote: (() => ! voted) }); } )
  ));

  const afterAlice = await getBalance(accAlice);
  const afterBob = await getBalance(accBob);

  console.log(`Alice went from ${beforeAlice} to ${afterAlice}.`);
  console.log(`Bob went from ${beforeBob} to ${afterBob}.`);

})();
