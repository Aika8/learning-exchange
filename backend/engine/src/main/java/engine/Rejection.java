package engine;

/** Why a command was refused. A refused command changes nothing and is not journalled. */
public enum Rejection {
    UNKNOWN_ACCOUNT,
    INVALID_NAME,
    ACCOUNT_EXISTS,
    UNKNOWN_INSTRUMENT,
    INVALID_ORDER,
    INVALID_AMOUNT,
    INSUFFICIENT_FUNDS,
    NO_LIQUIDITY,
    UNKNOWN_ORDER,
    NOT_OWNER,
    NOT_OPEN,
    LEVERAGE_NOT_ALLOWED,
    UNKNOWN_POSITION,
    UNKNOWN_DEPOSIT,
    MARKET_CLOSED,
    DEFAULTED
}
