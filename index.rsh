'reach 0.1';
'use strict';

const [ _, TEAM_A_WINS, DRAW, TEAM_B_WINS, TIMEOUT ] = makeEnum(4);

const Common = {
  showOutcome: Fun([UInt, UInt], Null),
};

export const main =
  Reach.App(
    { connectors: [ETH, ALGO] },
    [Participant('Organiser',
      { ...Common,
        getParams: Fun([], Object({ wagerPrice: UInt,
                                    deadline: UInt,
                                    aliceAddr: Address,
                                    bobAddr: Address })) }),
     ParticipantClass('Bettor',
      { ...Common,
        getVote: Fun([], Bool), // Fun([UInt, UInt], UInt)
        bettorWas: Fun([Address], Null),
        shouldVote: Fun([], Bool),
      }),
    ],
    (Organiser, Bettor) => {
      const showOutcome = (which, bal) => () => {
        each([Organiser, Bettor], () =>
          interact.showOutcome(which, bal)); };

      Organiser.only(() => {
        //const [ wagerPrice, deadline, aliceAddr, bobAddr ] =
         const params = declassify(interact.getParams());
         const [ wagerPrice, deadline, aliceAddr, bobAddr ] = [params.wagerPrice, params.deadline, params.aliceAddr, params.bobAddr];
      });
      Organiser.publish(wagerPrice, deadline, aliceAddr, bobAddr);

      const [ timeRemaining, keepGoing ] = makeDeadline(deadline);

      const [ forTeamA, forDraw, forTeamB ] =
        parallelReduce([ 0, 0, 0])
        .invariant(balance() == (forTeamA + forDraw + forTeamB) * wagerPrice)
        .while( keepGoing() )
        .case(Bettor, (() => ({
            msg: declassify(interact.getVote()),
            when: declassify(interact.shouldVote()),
          })),
          ((_) => wagerPrice),
          ((vote) => {
            const bettor = this;
            Bettor.only(() => interact.bettorWas(bettor));
            const [ nA, nD, nB ] = vote == 0 ? [ 1, 0, 0 ] : ( vote == 1 ? [ 0, 1,0 ] : [0,0,1]);
            return [ forTeamA + nA, forDraw + nD, forTeamB + nB ]; }))
        .timeout(timeRemaining(), () => {
          Anybody.publish();
          showOutcome(TIMEOUT,0)();
          return [ forTeamA, forDraw, forTeamB ]; });

      const outcome = forTeamA > forTeamB ? TEAM_A_WINS : ( forTeamB > forTeamA ? TEAM_B_WINS : DRAW);
      const toTeams = outcome == TEAM_A_WINS ? [2,0] : (outcome == TEAM_B_WINS ? [0,2] : [1,1]);

      const beforeBalance = balance();
      const alicePay = (balance()*toTeams[0])/2;
      const bobPay = (balance()*toTeams[1])/2;

      transfer(alicePay).to(aliceAddr);
      transfer(bobPay).to(bobAddr);
      transfer(balance()).to(Organiser);
      commit();
      showOutcome(outcome, beforeBalance)();
      exit();
    });
