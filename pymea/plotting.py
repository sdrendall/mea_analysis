import pandas as pd
import itertools as it
import seaborn as sns
import numpy as np
from pymea import matlab_compatibility as mc
from matplotlib import pyplot as plt

def plot_units_from_spike_table(spike_table):
    time_vector = spike_table['time'].map(mc.datetime_str_to_datetime)
    unit_table = spike_table.copy()
    del unit_table['time']
    num_units = len(unit_table.columns)
    #plt.figure(figsize=(10, 0.1 * num_units))
    for i, unit_name in enumerate(unit_table.columns):
        #plt.subplot(num_units, 1, i + 1)
        plt.figure()
        plot_unit(time_vector, unit_table[unit_name])
        plt.xlabel(unit_name)

def smooth(A, kernel_size=5, mode='same'):
    """
    Computes the moving average of A using a kernel_size kernel.
    """
    kernel = np.ones(kernel_size)/kernel_size
    return np.convolve(A, kernel, mode=mode)

def plot_unit(time, unit):
    plt.plot(time, unit)

def average_timecourse_plot(category_dataframe, **kwargs):
    """
    Generates an average timecourse with error bars for each category in category_dataframe
    see construct_categorized_dataframe for details on generateing the category_dataframe
    """
    sns.pointplot(x='time', y='spike_freq', hue='condition', data=category_dataframe, **kwargs)

def avg_timecourse_plot_2(category_dataframe, **kwargs):
    mean_freqs = category_dataframe.groupby(('condition', 'time'))['spike_freq'].mean()
    std_freqs = category_dataframe.groupby(('condition', 'time'))['spike_freq'].std()
    plt.errorbar()

def plot_unit_frequency_distributions(category_dataframe, **kwargs):
    """
    Plots the distribution of mean frequencies for units in each condition
    """
    mean_freqs_by_condition = category_dataframe.groupby(('condition', 'unit_name'))['spike_freq'].mean()
    mean_freqs_by_condition = mean_freqs_by_condition.rename('mean_freq').reset_index()
    for condition in mean_freqs_by_condition['condition']:
        sns.distplot(mean_freqs_by_condition.query('condition == @condition')['mean_freq'].map(np.log), bins=100)

def plot_mean_frequency_traces(category_dataframe, **kwargs):
    """
    Plots the mean frequency trace for each condition in category_dataframe
    """
    mean_freq_traces = category_dataframe.groupby(('condition', 'time'))['spike_freq'].mean()
    mean_freq_traces = mean_freq_traces.rename('spike frequency').reset_index() # Convert the multiindexed series back to a dataframe
    for condition in mean_freq_traces['condition'].unique():
        condition_trace = mean_freq_traces.query('condition == @condition')
        plt.plot(condition_trace['time'], condition_trace['spike frequency'])

    plt.xlabel('time')
    plt.ylabel('spike frequency')
    plt.title('Mean Spike Frequency Traces')
    plt.legend(mean_freq_traces['condition'].unique())

def construct_categorized_dataframe(data_table, filter_dict):
    """
    Takes the data from the matlab csv generated by preprocessing and applies filters to column names
    allowing for the categorization of data

    data_table - pandas DataFrame - should be populated from the .csv file generated by the 
        "generate_frequency_table.m" matlab script
    filter_dict - dictionary of the form {'condition_name': condition_filter}, where 
        condition_name is a string used to identify an experimental condition, and condition filter
        is a function that returns True for the unit_names corresponding to the desired condition
    """
    time_vector = data_table['time'].map(mc.datetime_str_to_datetime)
    unit_table = data_table.drop('time', axis=1)
    condition_dicts = (
        {
            'time': time_vector,
            'condition': condition_name,
            'spike_freq': condition_column,
            'unit_name': condition_column.name
        } for condition_name, condition_filter in filter_dict.iteritems()
            for condition_column in filter_unit_columns(condition_filter, unit_table)
    )
    condition_tables = it.imap(pd.DataFrame, condition_dicts)
    return pd.concat(condition_tables)

def filter_unit_columns(predicate, unit_table):
    """
    Generates columns from unit_table whose names satisfy the condition specified in predicate

    predicate - function that returns true for desired unit names
    unit_table - data_mat containing firing rates over time from each unit, with the time column ommited
    """
    unit_column_names = filter(predicate, unit_table.columns)
    for column_name in unit_column_names:
        yield unit_table[column_name]