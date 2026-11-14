package engine;

/** Why a command was refused. A refused command changes nothing and is not journalled. */
public enum Rejection {
    UNKNOWN_ACCOUNT,
    ACCOUNT_EXISTS,
    UNKNOWN_INSTRUMENT,
    INVALID_ORDER,
    INVALID_AMOUNT,
    INSUFFICIENT_FUNDS,
    NO_LIQUIDITY,
    UNKNOWN_ORDER,
    NOT_OWNER,
    NOT_OPEN
}
