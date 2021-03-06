//
//  ZSContextWatcher.m
//
//  Copyright 2010 Zarra Studios, LLC All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.

#import "ZSContextWatcher.h"
#import "ZSShared.h"

@interface ZSContextWatcher ()

@property (nonatomic, strong) NSManagedObjectContext *contextToWatch;
@property (nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinatorToWatch;

@end

@implementation ZSContextWatcher

- (id)initWithManagedObjectContextToWatch:(NSManagedObjectContext*)contextToWatch
{
  ZAssert(contextToWatch, @"Context is nil!");
  [super init];
    
  self.contextToWatch = contextToWatch;
  
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextUpdated:) name:NSManagedObjectContextDidSaveNotification object:nil];
  
  return self;
}

- (id)initWithPersistentStoreCoordinatorToWatch:(NSPersistentStoreCoordinator*)persistentStoreCoordinatorToWatch
{
  ZAssert(persistentStoreCoordinatorToWatch, @"Persistent Store Coordinator is nil!");
  [super init];
    
  self.persistentStoreCoordinatorToWatch = persistentStoreCoordinatorToWatch;
    
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(contextUpdated:) name:NSManagedObjectContextDidSaveNotification object:nil];
    
  return self;
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  delegate = nil;
  [masterPredicate release];
  masterPredicate = nil;
  [reference release];
  reference = nil;
  [_contextToWatch release];
  _contextToWatch = nil;
  [_persistentStoreCoordinatorToWatch release];
  _persistentStoreCoordinatorToWatch = nil;
  [super dealloc];
}

- (void)addEntityToWatch:(NSEntityDescription*)description withPredicate:(NSPredicate*)predicate;
{
  NSPredicate *entityPredicate = [NSPredicate predicateWithFormat:@"entity.name == %@", [description name]];
  NSPredicate *finalPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:entityPredicate, predicate, nil]];
  
  if (![self masterPredicate]) {
    [self setMasterPredicate:finalPredicate];
    return;
  }

  NSArray *array = [[NSArray alloc] initWithObjects:[self masterPredicate], finalPredicate, nil];
  finalPredicate = [NSCompoundPredicate orPredicateWithSubpredicates:array];
  [array release], array = nil;
  [self setMasterPredicate:finalPredicate];
}

- (void)contextUpdated:(NSNotification*)notification
{
  NSManagedObjectContext *incomingContext = [notification object];
  NSPersistentStoreCoordinator *incomingCoordinator = [incomingContext persistentStoreCoordinator];
  if (self.contextToWatch != nil) {
    if (incomingContext != self.contextToWatch) {
        return;
    }
  }
  else if (self.persistentStoreCoordinatorToWatch != nil) {
    if  (incomingCoordinator != self.persistentStoreCoordinatorToWatch) {
      return;
    }
  }
  if ([self reference]) {
    DLog(@"%@ entered", [self reference]);
  }
  NSMutableSet *inserted = [[[notification userInfo] objectForKey:NSInsertedObjectsKey] mutableCopy];
  if ([self masterPredicate]) [inserted filterUsingPredicate:[self masterPredicate]];
  NSMutableSet *deleted = [[[notification userInfo] objectForKey:NSDeletedObjectsKey] mutableCopy];
  if ([self masterPredicate]) [deleted filterUsingPredicate:[self masterPredicate]];
  NSMutableSet *updated = [[[notification userInfo] objectForKey:NSUpdatedObjectsKey] mutableCopy];
  if ([self masterPredicate]) [updated filterUsingPredicate:[self masterPredicate]];
  
  NSInteger totalCount = [inserted count] + [deleted count]  + [updated count];
  if (totalCount == 0) {
    [inserted release], inserted = nil;
    [deleted release], deleted = nil;
    [updated release], updated = nil;
    if ([self reference]) {
      DLog(@"%@----------fail on count", [self reference]);
    }
    return;
  }
  
  NSMutableDictionary *results = [[NSMutableDictionary alloc] init];
  if (inserted) [results setObject:inserted forKey:NSInsertedObjectsKey];
  if (deleted) [results setObject:deleted forKey:NSDeletedObjectsKey];
  if (updated) [results setObject:updated forKey:NSUpdatedObjectsKey];
  
  if ([[self delegate] respondsToSelector:[self action]]) {
    if ([self reference]) {
      DLog(@"%@++++++++++firing action", [self reference]);
    }
    [[self delegate] performSelectorOnMainThread:[self action] withObject:results waitUntilDone:YES];
  } else {
    if ([self reference]) {
      DLog(@"%@----------delegate doesn't respond", [self reference]);
    }
  }
  [results release], results = nil;
  [inserted release], inserted = nil;
  [deleted release], deleted = nil;
  [updated release], updated = nil;
}

@synthesize delegate;
@synthesize action;
@synthesize masterPredicate;
@synthesize reference;

@end
