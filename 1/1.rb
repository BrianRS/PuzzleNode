require "nokogiri"
require "bigdecimal"

rates_file = "RATES.xml"
trans_file = "TRANS.csv"
output_file = "OUTPUT.txt"
product = "DM1182"

def parse_rates(rates_file)
	rates_tree = Nokogiri::XML.parse File.open rates_file
	rate_tags = rates_tree.css "rate"
	rates = {}
	rate_tags.each do |rate|
		from = rate.css("from").text
		to = rate.css("to").text
		conv = BigDecimal.new(rate.css("conversion").text.to_f, 9)
		if rates[from]
			rates_from = rates[from]
			rates_from[to] = conv
		else
			rates[from] = { to => conv }
		end
	end

	#special cases: aud -> usd
	aud_to_usd = rates["CAD"]["USD"]*rates["AUD"]["CAD"]
	rates_aud = rates["AUD"]
	rates_aud["USD"] = aud_to_usd

	# eur -> usd
	eur_to_usd = rates["EUR"]["AUD"]*rates["AUD"]["USD"]
	rates_eur = rates["EUR"]
	rates_eur["USD"] = eur_to_usd
	rates
end

def parse_transactions(trans_file)
	sales = {}
	csv_lines = File.open(trans_file).readlines
	# the first line contains no data
	csv_lines = csv_lines[1..-1]
	csv_lines.each do |line|
		place, prod, cost = line.chomp.split ","
		if sales[prod]
			sales[prod] << cost
		else
			sales[prod] = [cost]
		end
	end
	sales
end

def find_sum(sales, product, rates)
	return nil unless sales[product]
	sum = BigDecimal.new(0)
	sales[product].each do |sale|
		val = convert(sale, rates)
		sum += val
	end
	sum	
end

def convert(sale, rates)
	price, currency = sale.split
	price = BigDecimal.new price, 9
	case currency
	when /USD/
		val = price
	when /CAD/
		val = price*rates["CAD"]["USD"]
	when /EUR/
		val = price*rates["EUR"]["USD"]
	when /AUD/
		val = price*rates["AUD"]["USD"]
	end
	unless val =~ /USD/
	 val = val.round(2, :banker)
	end
	val
end

rates = parse_rates(rates_file)
sales = parse_transactions(trans_file)
sum = find_sum(sales, product, rates)
output =  sum.to_f
out = File.new(output_file, "w")
out.write output 
out.write "\n"
out.close
puts output
