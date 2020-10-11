import pdb
import csv
import random
import numpy as np
import tensorflow as tf

class Environment:
	def __init__(self, csv_path):
		self.points = 0.00001
		self.spread_points = 5
		self.tp_points = 50
		self.sl_points = 50
		self.epsilon = 1.0

		self.dataset = []
		self.next_index = 0;

		with open(csv_path, newline='') as csvfile:
			reader = csv.reader(csvfile, delimiter=';')
			for row in reader:
				date, hour, \
				op, high, low, close, \
				tick_vol, vol, spread = row
				
				entry = {
					'date': date,
					'hour': hour,
					'tick_vol': float(tick_vol),
					'vol': float(vol),
					'open': float(op),
					'close': float(close),
					'high': float(high),
					'low': float(low),
				}
				self.dataset.append(entry)

		self.input_size = len(self.__build_state(0)[0])
		self.action_space = [0, 1, 2] # 0: pass, 1: long, 2: short

	def report(self):
		return "Long Trades: {} ({} won), Short Trades: {} ({} won), profit: {} (gross gain: {}, gross loss: {})".format(
			self.long_trades, self.long_trades_won, self.short_trades, self.short_trades_won,
			round(self.gross_profit + self.gross_loss), round(self.gross_profit), round(self.gross_loss)
		)

	def reset(self):
		self.next_index = 0
		self.short_trades = 0
		self.long_trades = 0
		self.long_trades_won = 0
		self.short_trades_won = 0
		self.short_trades_lost = 0
		self.gross_profit = 0
		self.gross_loss = 0

		return self.step(self.action_space[0])[0]

	def step(self, action):
		next_states = []
		rewards = []
		dones = []
        
		start_step_index = self.next_index
		reward, nindex = self.__calculate_reward(action, self.next_index)

		self.next_index = nindex
		for index in range(start_step_index, self.next_index): 
			next_state, has_next_state = self.__build_state(index)
			done = False
			if not has_next_state: done = True
			next_states.append(next_state)
			rewards.append(reward)
			dones.append(done)

		return (next_states, rewards, dones)


	def __build_state(self, index):
		if index >= len(self.dataset):
			return (None, False)

		row = self.dataset[index]
		hour = tf.keras.utils.to_categorical(row['hour'].split(':')[0], 24)
		
		state = [
			row['open'],
			row['low'],
			row['high'],
			row['tick_vol'],
			row['vol']
		]
		for i in range(index,index-48,-1):
			if not self.dataset[i]:
				state.append(self.dataset[i]['close'])
			else:
				state.append(row['close'])
		return (np.concatenate((hour, state)), True)

	def __calculate_reward(self, action, index):
		if action == 0: # pass
			reward = 0.3
			nindex = index + 1
		if action == 1: # long
			reward, nindex = self.__calculate_position_reward(True, index)
			self.long_trades += 1

			if reward > 0: self.long_trades_won += 1
			self.gross_profit += max(0, reward)
			self.gross_loss += min(0, reward)
		if action == 2: # short
			reward, nindex = self.__calculate_position_reward(False, index)
			self.short_trades += 1
            
			if reward > 0: self.short_trades_won += 1
			self.gross_profit += max(0, reward)
			self.gross_loss += min(0, reward)
		

		return (reward, nindex)


	def __calculate_position_reward(self, long, index):
		open_bid, open_ask = \
			(
				self.dataset[index]['close'] - self.__points(self.spread_points) / 2,
				self.dataset[index]['close'] + self.__points(self.spread_points) / 2
			)
		
		open_price = open_ask if long else open_bid
		if long:
			open_position_tp_price = open_bid + self.__points(self.tp_points) + self.__points(self.spread_points)
			open_position_sl_price = open_bid - self.__points(self.sl_points) + self.__points(self.spread_points)
		else:
			open_position_tp_price = open_ask - self.__points(self.tp_points) - self.__points(self.spread_points)
			open_position_sl_price = open_ask + self.__points(self.sl_points) - self.__points(self.spread_points)

		index += 1
		while index < len(self.dataset):
			if long:
				high_bid = self.dataset[index]['high'] - self.__points(self.spread_points) / 2
				low_bid = self.dataset[index]['low'] - self.__points(self.spread_points) / 2

				if low_bid <= open_position_sl_price:
					# print("LONG SL ({}):  From {} to {} ({})".format(index, open_price, open_position_sl_price, round((open_position_sl_price - open_price) / self.points)))
					return ((open_position_sl_price - open_price) / self.points, index + 1)
				if high_bid >= open_position_tp_price:
					# print("LONG TP ({}):  From {} to {} ({})".format(index, open_price, open_position_tp_price, round((open_position_tp_price - open_price) / self.points)))
					return ((open_position_tp_price - open_price) / self.points, index + 1)
			else:
				high_ask = self.dataset[index]['high'] + self.__points(self.spread_points) / 2
				low_ask = self.dataset[index]['low'] + self.__points(self.spread_points) / 2

				if high_ask >= open_position_sl_price:
					# print("SHORT SL ({}): From {} to {} ({})".format(index, open_price, open_position_sl_price, round((open_price - open_position_sl_price) / self.points)))
					return ((open_price - open_position_sl_price) / self.points, index + 1)
				if low_ask <= open_position_tp_price:
					# print("SHORT TP ({}): From {} to {} ({})".format(index, open_price, open_position_tp_price, round((open_price - open_position_tp_price) / self.points)))
					return ((open_price - open_position_tp_price) / self.points, index + 1)

			index += 1

		# if I'm here, it's end of the dataset
		return (0, index)


	def __points(self, val):
		return val * 0.00001

