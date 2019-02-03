# lgamma-and-gamma-using-SSE2
Implementation of the Log Gamma and Gamma functions in 64-bit assembly.

c-ish version:
lgamma(z):

	int j;
	double x, tmp, y, ser;
	if (z <= 0) return NAN;
	y = x = z;
	tmp = x + 5.2421875;
	tmp = (x + 0.5) * log(tmp) - tmp
  	ser = 0.999999999999997092;
  	for (int j = 0; j < 14; j++) 
  		ser += cof[j] / ++y;
	
 	return tmp + log(2.5066282746310005 * ser / x);

gamma(z):

  	return exp(lgamma(z))
