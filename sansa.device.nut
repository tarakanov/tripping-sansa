// обработчик сенсора просыпания
function standby_handler() {
    
}

function standby() {
    // весы в режиме ожидания
    weight_en_l.write(1);
    server.log("весы в режиме ожидания");
    
    local STANDBY_TIME = 20; //время в режиме ожидания (секунды)
    local standby_start = hardware.millis();
    while ((hardware.millis() - standby_start) < STANDBY_TIME*1000) {
               /* if (myScales.weight_detect(30)) {
                    
                    weight_en_l.write(0);
                    imp.sleep(0.2);
                    weight_en_l.write(1);
                    
                    
                    local current_weight = myScales.read();
                    send_weight(current_weight);
                    
                    server.log(format("Weight: %.1f Kg", current_weight)); // процесс измерения массы
                    
                    
                    
                    
                    //рестарт таймаута после детекции массы
                    standby_start = hardware.millis();
                    server.log("рестарт таймаута");
                } */
                if (myScales.weight_detect(10)) {
                    imp.sleep(2);
                    local current_weight = myScales.auto_read();
                    send_weight(current_weight);
                    
                    server.log(format("Weight: %.1f Kg", current_weight)); // процесс измерения массы
                    
                }
            }
    // весы в режиме сна
    weight_en_l.write(0);
    imp.onidle( function() {
        server.log("весы перешли в спящий режим");
        //server.sleepfor(999999999); //глубокий спящий режим 
        imp.setpowersave(1); //экономичный расход wifi
    });
}

// обработка нажатия кнопки
function buttonPress() {
    local state = button.read();
    imp.sleep(0.02); //software debounce
    if (state == 1)
    {
        server.log("Release");
        
        weight_en_l.write(0);
        imp.sleep(0.2);
        weight_en_l.write(1);
                    
                    
        local current_weight = myScales.read();
        send_weight(current_weight);
                    
        server.log(format("Weight: %.1f Kg", current_weight)); // процесс измерения массы
                    
                    
    } else
    {
        server.log("Press");
    }
}




// класс описание полного моста для измерения массы тела
class w_bridge { 

    // калибровочные переменные для моста
    vbridge_a = null; // напряжение моста без массы
    weight_a = null; // напряжение моста с калибровочной массой
    vbridge_b = null; // калибровочная масса в кг
    weight_b   = null; // масса без массы

	// analog input pin
	p_bridge 		= null;
	p_ref           = null;
	points_per_read = null;
    vbridge_tol    = null; // толерантность изменения напряжения моста
    
	constructor(pin, pinref, v_load_a, m_load_a, v_load_b, m_load_b, points = 10, tol = 10) {
		this.p_bridge = pin;
		this.p_ref = pinref;
		this.p_bridge.configure(ANALOG_IN);
        this.p_ref.configure(ANALOG_IN);
        
		// force all of these values to floats in case they come in as integers
		this.vbridge_a = v_load_a * 1.0;
		this.weight_a = m_load_a * 1.0;
		this.vbridge_b = v_load_b * 1.0;
		this.weight_b = m_load_b * 1.0;
		this.points_per_read = points * 1.0;
		this.vbridge_tol = tol * 1.0;
	}

	// вычисление массы на весах
	function read() {
		local vbridge_raw = 0; //моментальное значение напряжения моста
		local vdda_raw = 0; //моментальное значение напряжение питания
		local vref_raw = 0; //моментальное значение напряжение опорного напряжения
		server.log("начало измерения");
		for (local i = 0; i < points_per_read; i++) {
		    vref_raw += p_ref.read();
		    vbridge_raw += p_bridge.read();
		    vdda_raw += hardware.voltage();
		}
		
		
		local vdda = (vdda_raw / points_per_read); // среднее значение напряжения питания
		local v_bridge = (vbridge_raw / points_per_read) * (vdda / 65535.0); // среднее значение напряжение моста
		local vref = (vref_raw / points_per_read) * (vdda / 65535.0); // среднее значение опорного напряжения
		v_bridge = v_bridge - vref;
		server.log("конец измерения. vref: " + vref + " v_bridge: " + v_bridge + "количество замеров: " + points_per_read)
		local weight = (weight_a - weight_b) * (v_bridge - vbridge_a) / (vbridge_a - vbridge_b) + weight_a; // вычисление массы
		return weight;
	}
	
	function weight_detect(tolerance) {
	    local vbridge_start = p_bridge.read();
	    imp.sleep(0.1);
	    if (math.abs(vbridge_start - p_bridge.read()) > (vbridge_start * tolerance * 0.01)) {
	        return 1;
	    } else {
	        return 0;
	    }
	    
	}
	
	function stable_read() {
	    if (!weight_detect(10)) {return(this.read());}
	}
	
	function auto_read() {
	    //local weight_raw = p_brigde.read();
	    //ожидание веса
	    local b = 0;
	    local i = 0;
	   /* while (!this.weight_detect(10)) {
	       // server.log("b= " + b);
	        weight_en_l.write(b);
	        if (i) {
	            b = 1;
	        } else {
	            b = 0;
	        }
	        i = !i;
	    }*/
	    //ждем, пока вес успокоится
	    while (this.weight_detect(2)) {
	        weight_en_l.write(1);
	    }
	    //вычисляем вес
	    weight_en_l.write(0);
	    imp.sleep(1);
	    weight_en_l.write(1);
	    return this.read();
	}

}

function send_weight(weight) {
    local id = hardware.getdeviceid();
    local datapoint = {
        "id" : id,
        "weight" : format("%.2f", weight)
    }
    agent.send("data", datapoint);
    return;
}

//константы
const calib_v_a = -0.476;
const calib_m_a = 64.4;
const calib_v_b = -0.0589;
const calib_m_b = 7.4;


// кнопка запуска измерения
button <- hardware.pin7;
// датчик просыпания
wakeup_sensor <- hardware.pin1;

//индикатор процесса измерения (горит, когда процесс запущен)
weight_en_l <- hardware.pin9;
weight_en_l.configure(DIGITAL_OUT);


// пин, на котором сидит Vo от INA126
weight_sns <- hardware.pin2;
// пин опорного напряжения
weight_ref <- hardware.pin5;

// инициализирование класса полного моста
myScales <- w_bridge(weight_sns, weight_ref, calib_v_a, calib_m_a, calib_v_b, calib_m_b, 10, 10);

// задаём реакцию на нажатие кнопки - запуск обработчика
wakeup_sensor.configure(DIGITAL_IN_WAKEUP, standby);
//button.configure(DIGITAL_IN_PULLUP, buttonPress);
server.log("Весы онлайн");
