import random
import math
import numpy as np
from collections import deque
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import Dense
from tensorflow.keras.layers import Dropout
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.regularizers import l2
from environment import Environment

EPOCHS = 10
THRESHOLD = 195
MONITOR = True

class DQN:
	def __init__(self, env_string, batch_size=128):
		self.memory = deque(maxlen=100000)
		self.env = Environment2('EURUSD_H1.csv')
		self.input_size = self.env.input_size
		self.action_size = len(self.env.action_space)
		self.batch_size = batch_size
		self.gamma = 1.0
		self.epsilon = 1.0
		self.epsilon_min = 0.01
		self.epsilon_decay = 0.9998
		alpha=0.01
		alpha_decay=0.01
		dropout = 0.3

		# Init model
		self.model = Sequential()
		self.model.add(Dense(8, input_dim=self.input_size, activation='tanh', kernel_regularizer=l2(0.01), activity_regularizer=l2(0.01)))
		self.model.add(Dropout(dropout))
		self.model.add(Dense(16, activation='tanh', kernel_regularizer=l2(0.01), activity_regularizer=l2(0.01)))
		self.model.add(Dropout(dropout))
		self.model.add(Dense(self.action_size, activation='linear'))
		self.model.compile(loss='mse', optimizer=Adam(lr=alpha, decay=alpha_decay))

		self.model.summary()

	def remember(self, state, action, reward, next_state, done):
		self.memory.append((state, action, reward, next_state, done))

	def replay(self, batch_size):
		x_batch, y_batch = [], []
		minibatch = random.sample(self.memory, min(len(self.memory),batch_size))

		for state, action, reward, next_state, done in minibatch:
			y_target = self.model.predict(state)
			# print("action: {}, reward: {}".format(action, reward))
			#print(y_target[0])
			# y_target[0][action] = reward if done else reward + self.gamma * np.max(self.model.predict(next_state)[0])
			#y_target[0] = [0, 0, 0]
			y_target[0][action] = max(min(reward, 1), 0)
			#print(y_target[0])
			x_batch.append(state[0])
			y_batch.append(y_target[0])

		self.model.fit(np.array(x_batch), np.array(y_batch), batch_size=len(x_batch), verbose=1)

	def train(self):
		scores = deque(maxlen=100)
		avg_scores = []
		for e in range(EPOCHS):
			print("Training ({}):".format(e + 1))

			state = self.env.reset()
			state = self.preprocess_state(state)
			done = False

			while not done:
				action = self.choose_action(state, self.epsilon)
				# print(action)
				next_state, reward, done = self.env.step(action)
				next_state = self.preprocess_state(next_state)
				self.remember(state, action, reward, next_state, done)
				state = next_state
				self.epsilon = max(self.epsilon_min, self.epsilon_decay*self.epsilon) # decrease epsilon
				if self.env.next_index >= 70000: break

			self.replay(self.batch_size)
			print(self.env.report())

			# test on unoptimized data
			print("Evaluating: ")

			state = self.env.reset()
			self.env.next_index = 70001
			state = self.preprocess_state(state)
			done = False

			while not done:
				action = self.choose_action(state, -1)
				next_state, reward, done = self.env.step(action)
				state = self.preprocess_state(next_state)
				if self.env.next_index >= 100000: break

			print(self.env.report())
			print()


		print('Did not solve after {} episodes :('.format(e))
		return avg_scores

	def choose_action(self, state, epsilon):
		if np.random.random() <= epsilon:
			return random.choice(self.env.action_space)
		else:
			return np.argmax(self.model(state, training=epsilon>0))


	def preprocess_state(self, state):
		return np.reshape(state, [1, self.input_size])

env_string = 'CartPole-v0'
agent = DQN(env_string)
scores = agent.train()
