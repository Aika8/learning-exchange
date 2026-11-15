package app.web;

import app.web.Dto.Problem;
import application.CommandRejected;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

/** Turns refusals into {@code Problem {code, message}} with the status the contract promises. */
@RestControllerAdvice
public class ApiErrors {

    @ExceptionHandler(CommandRejected.class)
    ResponseEntity<Problem> rejected(CommandRejected e) {
        HttpStatus status = switch (e.reason()) {
            case INSUFFICIENT_FUNDS, NO_LIQUIDITY -> HttpStatus.UNPROCESSABLE_CONTENT;
            case UNKNOWN_INSTRUMENT, UNKNOWN_ORDER, UNKNOWN_POSITION, UNKNOWN_DEPOSIT -> HttpStatus.NOT_FOUND;
            case LEVERAGE_NOT_ALLOWED -> HttpStatus.UNPROCESSABLE_CONTENT;
            case NOT_OWNER -> HttpStatus.FORBIDDEN;
            case NOT_OPEN, ACCOUNT_EXISTS -> HttpStatus.CONFLICT;
            case UNKNOWN_ACCOUNT -> HttpStatus.UNAUTHORIZED;
            case INVALID_NAME, INVALID_ORDER, INVALID_AMOUNT -> HttpStatus.BAD_REQUEST;
        };
        return ResponseEntity.status(status).body(new Problem(e.reason().name(), e.reason().name().toLowerCase().replace('_', ' ')));
    }

    @ExceptionHandler(DevAuth.Unauthorized.class)
    ResponseEntity<Problem> unauthorized(DevAuth.Unauthorized e) {
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(new Problem("UNAUTHORIZED", e.getMessage()));
    }

    @ExceptionHandler({ApiController.BadRequest.class, HttpMessageNotReadableException.class,
            MethodArgumentTypeMismatchException.class, IllegalArgumentException.class})
    ResponseEntity<Problem> badRequest(Exception e) {
        return ResponseEntity.badRequest().body(new Problem("BAD_REQUEST", e.getMessage()));
    }
}
