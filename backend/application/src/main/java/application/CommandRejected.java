package application;

import engine.Rejection;

/** A command the exchange refused; adapters turn it into a 4xx answer. */
public final class CommandRejected extends RuntimeException {

    private final Rejection reason;

    public CommandRejected(Rejection reason) {
        super(reason.name());
        this.reason = reason;
    }

    public Rejection reason() {
        return reason;
    }
}
