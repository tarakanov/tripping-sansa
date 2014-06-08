// battery check function
function batterycheck()
{
    if (Vdd => Vddmin) {
        standby();
    } else {
        faultstate(lowbattery);
    }
}

// fault state function
function faultstate(state) {
    switch {
        case lowbattery: LED(blink2Hz);
        case measurefault: LED(blink3Hz);
        case calibrationfault: LED(blink4Hz);
        case sendfault: LED (blink5Hz);
    }
    deepsleep();
}

// stand-by function
function standby()
{
    while() {
        LED(ready);
        count_to_sec(30);
        if countdone {
            deepsleep();
        }
        if weightdetected() {
            measureroutine();
        }
    }
}
